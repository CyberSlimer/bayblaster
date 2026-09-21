"""Pacing simulation mirroring Constants.swift + Loadout.swift + WaterSkipSystem + WorldSpawner.

Mirrors the resolved per-run numbers the game actually uses, which since the locker update
means five layers, in the same order as UpgradeConfig.init:
    upgrade tiers -> crew perk -> equipped gear -> prestige -> daily modifier
plus the rider's in-flight ability, which a competent player fires whenever it is off
cooldown and it would help.

Run: python3 sim.py
"""
import math, random, statistics

PPM = 10.0                       # points per meter
G = -400.0                       # gravity pt/s^2
DT = 1/120

# Upgrade tables (index = tier, 0 = base)
LAUNCH_SPEED = [1250, 1450, 1680, 1950, 2250, 2600]
AIR_DRAG     = [0.12, 0.10, 0.085, 0.07, 0.055, 0.04]     # per second (linear)
HULL_MAX     = [100, 130, 160, 200, 250, 300]
SKIP_H_RET   = [0.88, 0.895, 0.91, 0.925, 0.94, 0.95]
ROCKET_COUNT = [0, 1, 2, 3, 3, 3]
ROCKET_STR   = [0, 420, 420, 420, 600, 800]
LURE_BOOST   = [1.0, 1.25, 1.5, 1.8, 2.1, 2.5]

SKIP_V_REST = 0.62
SKIP_RET_CEIL  = 0.985      # Tuning.skipRetentionCeiling
SKIP_REST_CEIL = 0.90       # Tuning.skipRestitutionCeiling
FORCED_SKIP_MIN_BOUNCE = 260
SKIP_MIN_VY = 90.0
SKIP_MAX_ANGLE = math.radians(42)
DIVE_MAX_ANGLE = math.radians(64)
DIVE_REST_BONUS = 1.22
DIVE_GRAV_MULT = 1.6
PLOW_DRAG = 1.8      # per second
END_SPEED = 45.0
HARD_IMPACT_T = [1400, 1550, 1700, 1900, 2100, 2300]
HARD_DMG_PER_100 = 6.0
WATER_Y = 0.0

# skip combos
COMBO_COIN_STEP = 3
PERFECT_ANGLE = math.radians(22)
PERFECT_SPEED_BONUS = 1.04
PERFECT_COINS = 15

# spawn
SPAWN_INTERVAL_M = (55, 110)
BASE_HAZ_FRAC = 0.32   # fraction of spawns that are hazards at 0m
HAZ_FRAC_AT_5000 = 0.5
HAZ_REPEAT_PENALTY = 0.45
COIN_ARC_CHANCE = 0.22
COIN_ARC_COUNT = (6, 9)
COIN_ARC_SPACING = 46
COIN_ARC_HEIGHT = (80, 420)
COIN_ARC_RISE = 90
COIN_VALUE = 5

# entity effects
MINE_DMG, MINE_UP, MINE_SPEED = 35, 650, 0.8
JELLY_DMG, JELLY_VY, JELLY_STUN = 10, 0.5, 1.5
WHIRL_PULL, WHIRL_DRAG = 900, 0.35
DOLPHIN_UP, DOLPHIN_FWD = 700, 260
BALLOON_SEC, BALLOON_G, BALLOON_LIFT = 2.2, 0.3, 220

# ---------------------------------------------------------------- crew (Core/Crew.swift)
# (launch_mult, hull_mult, drag_mult, retention_bonus, bonus_rockets, coin_mult,
#  damage_mult, cooldown_mult, ability)
CREW = {
    'marlow':  (1.00, 1.00, 1.00, 0.000, 0, 1.0, 1.00, 0.8, 'tuck'),
    'bristle': (1.00, 1.35, 0.88, 0.012, 0, 1.0, 1.00, 1.0, 'puff'),
    'nixie':   (1.00, 1.00, 0.68, 0.000, 0, 1.0, 1.00, 1.0, 'glide'),
    'gilly':   (1.00, 1.00, 1.00, 0.000, 1, 1.0, 1.00, 1.0, 'inkjet'),
    'bruno':   (1.00, 1.00, 0.88, 0.045, 0, 1.0, 1.00, 1.0, 'slam'),
    'tock':    (1.00, 1.25, 0.80, 0.000, 0, 1.0, 0.50, 1.0, 'shell'),
    'pip':     (1.00, 1.00, 1.00, 0.000, 0, 1.7, 1.00, 1.0, 'swoop'),
    'chum':    (1.20, 0.85, 0.80, 0.000, 0, 1.0, 1.00, 1.0, 'frenzy'),
}

# ---------------------------------------------------------------- abilities
ABILITY = {   # (duration_s, cooldown_s)
    'tuck':   (1.2, 7), 'puff':   (2.2, 7), 'glide': (1.6, 7), 'shell':  (0.0, 6),
    'inkjet': (0.0, 5), 'slam':   (0.0, 6), 'swoop': (0.0, 5), 'frenzy': (4.0, 10),
}
AB_MIN_CD = 2.0
TUCK_DRAG_MULT, TUCK_PUSH = 0.55, 100
PUFF_REST_MULT = 1.15
GLIDE_G_MULT, GLIDE_PUSH = 0.55, 70
SHELL_CHARGES = 2
INKJET_FWD, INKJET_UP = 150, 40
SLAM_DOWN, SLAM_REST_MULT, SLAM_FWD_BONUS = 900, 1.50, 1.22
SWOOP_RANGE, SWOOP_KEEP, SWOOP_MIN_DY = 900, 1.08, -200
FRENZY_COIN_MULT = 2.0

# ---------------------------------------------------------------- gear (Core/Gear.swift)
# Only the fields a part actually changes; everything else defaults to a no-op.
GEAR = {
    'wheels':         dict(slot='hull',    plow_mult=0.35),
    'pontoons':       dict(slot='hull',    skip_angle_bonus=14, drag_mult=1.06),
    'springKeel':     dict(slot='hull',    rest_mult=1.26),
    'stormSail':      dict(slot='rig',     sail=32, storm_forward=True),
    'boxKite':        dict(slot='rig',     grav_mult=0.84),
    'jetVent':        dict(slot='rig',     rocket_mult=1.15, bonus_rockets=1),
    'coinMagnet':     dict(slot='trinket', magnet=600),
    'luckyHorseshoe': dict(slot='trinket', boost_mult=2.0, arc_bonus=0.28),
    'barnaclePlate':  dict(slot='trinket', launch_mult=0.96, damage_mult=0.5),
}

# ---------------------------------------------------------------- launchers
# (aim_mode, angle_lo, angle_hi, min_power, speed_mult, muzzle_y, sweet, sweet_hw,
#  sweet_bonus, skip_angle_bonus, hard_impact_bonus)
LAUNCHERS = {
    'cannon':    ('twoSweep',   15, 75, 0.45, 1.00, 60, 0.00, 0.00, 1.00, 0, 0),
    'rodReel':   ('castTiming', 25, 65, 0.40, 0.95, 74, 0.82, 0.11, 1.28, 0, 0),
    'slingshot': ('charge',     20, 70, 0.30, 1.18, 52, 0.00, 0.00, 1.00, 0, 0),
    'torpedo':   ('twoSweep',    6, 28, 0.60, 1.12, 34, 0.00, 0.00, 1.00, 8, 600),
}

PRESTIGE_COIN_PER_LEVEL = 0.25

# ---------------------------------------------------------------- daily modifiers
DAILY = {
    'doubleCoins':   dict(coin=2.0),
    'glassHull':     dict(coin=1.6, hull=0.4),
    'noRockets':     dict(coin=2.6, rockets=-99),
    'headwind':      dict(coin=2.0, drag=1.8, launch=1.1),
    'squally':       dict(coin=1.5, haz_bonus=0.18),
    'featherweight': dict(grav=0.7, launch=0.85),
    'rocketRush':    dict(rockets=3, drag=1.5),
    'ironFish':      dict(coin=1.3, launch=0.9, damage=0.4),
}


def resolve(tiers, crew='marlow', gear=(), prestige=0, daily=None, launcher='cannon'):
    """Mirror of UpgradeConfig.init — the five layers, in the same order."""
    L, H, R, A, U = tiers
    lspec = LAUNCHERS[launcher]
    l_skip_bonus, l_hard_bonus = lspec[9], lspec[10]
    lm, hm, dm, rb, br, cm_, dmg, cdm, ability = CREW[crew]
    d = DAILY.get(daily, {})

    speed      = LAUNCH_SPEED[L] * lm
    hull       = HULL_MAX[H] * hm
    retention  = SKIP_H_RET[H] + rb
    rockets    = ROCKET_COUNT[R] + br
    rocket_str = ROCKET_STR[R]
    drag       = AIR_DRAG[A] * dm
    boost_mult = LURE_BOOST[U]

    grav, plow, skip_angle_bonus = 1.0, PLOW_DRAG, float(l_skip_bonus)
    rest, sail, magnet = SKIP_V_REST, 0.0, 0.0
    arc_chance, coin_mult, damage = COIN_ARC_CHANCE, cm_, dmg
    storm_forward = False

    for g in gear:
        m = GEAR[g]
        plow *= m.get('plow_mult', 1)
        skip_angle_bonus += m.get('skip_angle_bonus', 0)
        rest *= m.get('rest_mult', 1)
        drag *= m.get('drag_mult', 1)
        grav *= m.get('grav_mult', 1)
        speed *= m.get('launch_mult', 1)
        rocket_str *= m.get('rocket_mult', 1)
        rockets += m.get('bonus_rockets', 0)
        sail += m.get('sail', 0)
        storm_forward = storm_forward or m.get('storm_forward', False)
        magnet = max(magnet, m.get('magnet', 0))
        boost_mult *= m.get('boost_mult', 1)
        arc_chance += m.get('arc_bonus', 0)
        damage *= m.get('damage_mult', 1)

    coin_mult *= 1 + prestige * PRESTIGE_COIN_PER_LEVEL

    speed   *= d.get('launch', 1)
    hull    *= d.get('hull', 1)
    drag    *= d.get('drag', 1)
    grav    *= d.get('grav', 1)
    rockets += d.get('rockets', 0)
    coin_mult *= d.get('coin', 1)
    damage  *= d.get('damage', 1)
    sail    += d.get('sail', 0)

    if rocket_str <= 0 and rockets > 0:
        rocket_str = ROCKET_STR[1]

    return dict(
        speed=speed, hull=max(1, hull), retention=min(retention, SKIP_RET_CEIL),
        hard_t=HARD_IMPACT_T[H] + l_hard_bonus, rockets=max(0, rockets), rocket_str=rocket_str,
        drag=max(0, drag), grav=grav, plow=plow, sail=sail, storm_forward=storm_forward,
        skip_max=SKIP_MAX_ANGLE + math.radians(skip_angle_bonus),
        dive_max=DIVE_MAX_ANGLE + math.radians(skip_angle_bonus),
        rest=min(rest, SKIP_REST_CEIL), boost_mult=boost_mult,
        arc_chance=min(max(arc_chance, 0), 0.8), coin_mult=coin_mult, damage=damage,
        magnet=magnet, haz_bonus=d.get('haz_bonus', 0),
        ability=ability, ab_cd=max(AB_MIN_CD, ABILITY[ability][1] * cdm),
        ab_dur=ABILITY[ability][0], launcher=launcher,
    )


# ---------------------------------------------------------------- barriers (breakable walls)
BARRIER_START_M = 120
BARRIER_INTERVAL_M = (240, 420)
BARRIER_BLOCK = 64
BARRIER_BLOCKS = (4, 12)
BARRIER_TALL_CHANCE = 0.25        # …and one wall in four is a towering sky gate
BARRIER_TALL_BLOCKS = (14, 26)
BARRIER_BASE_TOUGH = 380
BARRIER_TOUGH_PER_M = 0.18
BARRIER_MAX_TOUGH = 1400
BARRIER_SMASH_KEEP = 0.94
BARRIER_SMASH_COINS = 9
BARRIER_BOUNCE_MULT = 0.18
BARRIER_BOUNCE_BACK = 46
BARRIER_DAMAGE = 12

# ---------------------------------------------------------------- the high air
HIGH_START_H, HIGH_TOP_H = 900, 3000
HIGH_SPAWN_START_M = 60
HIGH_SPAWN_INTERVAL_M = (90, 170)
CRATE_COINS, CRATE_KEEP = 30, 0.97
BLIMP_UP, BLIMP_KEEP, BLIMP_FWD = 760, 0.35, 120
RING_SPEED, RING_COINS = 420, 20
JET_PUSH, JET_LIFT = 900, 90

# kind -> high-air weight
HIGH_AIR = {'blimp': 24, 'ring': 26, 'jet': 18, 'balloon': 20, 'birds': 22, 'cloud': 14}
HIGH_UNLOCK_M = {'blimp': 400, 'jet': 900, 'ring': 80}

BOOSTS = {
    'buoy':    dict(w=30, y=(0, 0), r=28,  ),
    'whale':   dict(w=12, y=(0, 0), r=40),
    'motor':   dict(w=18, y=(40, 260), r=26),
    'birds':   dict(w=15, y=(300, 900), r=120),
    'coins':   dict(w=15, y=(60, 500), r=24),
    'fuel':    dict(w=10, y=(30, 300), r=24),
    'dolphin': dict(w=14, y=(0, 0), r=38),
    'balloon': dict(w=12, y=(200, 650), r=34),
    'crate':   dict(w=14, y=(0, 220), r=26),
    'ring':    dict(w=10, y=(200, 1800), r=44),
}
HAZ = {
    'rock':  dict(w=35, y=(0, 0), r=34),
    'net':   dict(w=25, y=(0, 0), r=40),
    'shark': dict(w=20, y=(0, 0), r=34),
    'cloud': dict(w=20, y=(350, 900), r=110),
    'mine':  dict(w=18, y=(0, 0), r=30),
    'jelly': dict(w=20, y=(20, 180), r=28),
    'whirl': dict(w=15, y=(0, 0), r=90),
}
WATER_HAZ = {'rock', 'net', 'shark', 'mine', 'whirl'}
UNLOCK_M = {'shark': 150, 'balloon': 200, 'jelly': 250, 'cloud': 300, 'dolphin': 300, 'mine': 400,
            'whirl': 700, 'ring': 80, 'blimp': 400, 'jet': 900}
ZONES = {'birds', 'cloud', 'whirl', 'jet'}

def pick(table, metres=1e9):
    table = {k: v for k, v in table.items() if UNLOCK_M.get(k, 0) <= metres}
    tot = sum(v['w'] for v in table.values())
    r = random.random()*tot
    for k, v in table.items():
        r -= v['w']
        if r <= 0: return k
    return k

def run(tiers, player_skill=0.6, crew='marlow', gear=(), prestige=0, daily=None,
        launcher='cannon', verbose=False):
    c = resolve(tiers, crew, gear, prestige, daily, launcher)
    mode, a_lo, a_hi, min_pow, spd_mult, muzzle_y, sweet, sweet_hw, sweet_bonus, _sab, _hib = LAUNCHERS[launcher]

    # --- aim: a decent player lands near the middle of the angle band, and hits the timing
    # window `player_skill` of the time.
    mid = (a_lo + a_hi) / 2
    span = (a_hi - a_lo) / 2
    ang = math.radians(min(max(random.gauss(mid, span * 0.28), a_lo), a_hi))
    if mode == 'castTiming':
        hit = random.random() < player_skill
        power = random.uniform(sweet - sweet_hw, sweet + sweet_hw) if hit else random.uniform(0.3, 1.0)
        spd_mult *= sweet_bonus if hit else 1.0
    elif mode == 'charge':
        # Held to near-full most of the time; a bad read lets the band snap.
        if random.random() < player_skill:
            power = random.uniform(0.85, 1.0)
        else:
            power = 0.30 if random.random() < 0.5 else random.uniform(0.4, 0.8)
    else:
        power = random.uniform(0.75, 1.0)

    v = c['speed'] * spd_mult * (min_pow + (1 - min_pow) * power)
    vx, vy = v * math.cos(ang), v * math.sin(ang)
    x, y = 0.0, float(muzzle_y)

    hull = c['hull']
    rockets = c['rockets']
    coins = 0
    state = 'fly'
    t = 0.0
    diving = False
    next_spawn = 400.0
    next_high = HIGH_SPAWN_START_M * PPM
    next_wall = BARRIER_START_M * PPM
    ents = []
    walls = []            # [x, height, toughness, broken]
    smashed = 0
    prev_x = 0.0
    skips = 0
    hazards_hit = 0
    zone = None
    max_flight = 0
    cur_flight = 0
    combo = 0
    best_combo = 0
    perfects = 0
    stun = 0.0
    floating = 0.0
    last_water_haz = False
    # ability state
    ab_cd = 0.0
    ab_active = 0.0
    ab_uses = 0
    shields = 0
    slam_armed = False

    def pay(n):
        m = c['coin_mult'] * (FRENZY_COIN_MULT if (c['ability'] == 'frenzy' and ab_active > 0) else 1)
        return max(n, int(round(n * m)))

    while True:
        # ---- spawn ahead
        while next_spawn < x + 6000:
            d_m = next_spawn / PPM
            haz_frac = BASE_HAZ_FRAC + (HAZ_FRAC_AT_5000 - BASE_HAZ_FRAC) * min(1, d_m / 5000)
            haz_frac = min(max(haz_frac + c['haz_bonus'], 0), 0.85)
            if last_water_haz:
                haz_frac *= HAZ_REPEAT_PENALTY
            bw = (1 - haz_frac) * c['boost_mult']
            density = 1.0 + min(1.0, d_m / 4000) * 0.6
            if random.random() < bw / (bw + haz_frac):
                if random.random() < c['arc_chance']:
                    n = random.randint(*COIN_ARC_COUNT)
                    peak = random.uniform(*COIN_ARC_HEIGHT)
                    rise = COIN_ARC_RISE * random.uniform(0.5, 1.2)
                    for i in range(n):
                        u = i / max(n - 1, 1)
                        curve = 1 - ((u - 0.5) * 2) ** 2
                        ents.append([next_spawn + i * COIN_ARC_SPACING,
                                     max(peak - rise + rise * curve, 30), 20, 'coin', False, False])
                    next_spawn += n * COIN_ARC_SPACING
                    last_water_haz = False
                    next_spawn += random.uniform(*SPAWN_INTERVAL_M) * PPM / density
                    continue
                k = pick(BOOSTS, d_m); spec = BOOSTS[k]; is_h = False
            else:
                k = pick(HAZ, d_m); spec = HAZ[k]; is_h = True
            last_water_haz = k in WATER_HAZ
            ents.append([next_spawn, random.uniform(*spec['y']), spec['r'], k, is_h, False])
            next_spawn += random.uniform(*SPAWN_INTERVAL_M) * PPM / density

        # high-air track: fills the sky above HIGH_START_H, which used to be empty
        while next_high < x + 6000:
            d_m = next_high / PPM
            pool = {k: w for k, w in HIGH_AIR.items() if HIGH_UNLOCK_M.get(k, 0) <= d_m}
            if pool:
                tot = sum(pool.values())
                r = random.random() * tot
                kk = list(pool)[-1]
                for k2, w2 in pool.items():
                    r -= w2
                    if r <= 0:
                        kk = k2
                        break
                spec2 = BOOSTS.get(kk) or HAZ.get(kk) or dict(r=90)
                ents.append([next_high, random.uniform(HIGH_START_H, HIGH_TOP_H),
                             spec2.get('r', 90) if kk not in ('blimp', 'jet') else (70 if kk == 'blimp' else 170),
                             kk, kk == 'cloud', False])
            next_high += random.uniform(*HIGH_SPAWN_INTERVAL_M) * PPM

        # barrier track: one breakable wall at a steady cadence, toughening with distance
        while next_wall < x + 6000:
            d_m = next_wall / PPM
            tough = min(BARRIER_MAX_TOUGH, BARRIER_BASE_TOUGH + d_m * BARRIER_TOUGH_PER_M)
            tall = random.random() < BARRIER_TALL_CHANCE
            nblocks = random.randint(*(BARRIER_TALL_BLOCKS if tall else BARRIER_BLOCKS))
            walls.append([next_wall, BARRIER_BLOCK * nblocks, tough, False, False])
            next_wall += random.uniform(*BARRIER_INTERVAL_M) * PPM

        stun = max(0.0, stun - DT)
        floating = max(0.0, floating - DT)
        ab_cd = max(0.0, ab_cd - DT)
        ab_active = max(0.0, ab_active - DT)

        # ---- ability: fire it whenever it is ready and it would actually help
        if state == 'fly' and ab_cd <= 0 and stun <= 0 and random.random() < player_skill:
            a = c['ability']
            want = False
            if a in ('tuck', 'glide'):        want = vy < 200                 # on the way down / at apex
            elif a == 'puff':                 want = y < 260 and vy < 0       # about to land
            elif a == 'slam':                 want = vy < 0 and 150 < y < 700 and vx > 400
            elif a == 'inkjet':               want = abs(vy) < 260
            elif a == 'shell':                want = shields == 0
            elif a == 'swoop':                want = any(0 < e[0] - x < SWOOP_RANGE and e[1] - y > SWOOP_MIN_DY and not e[5] and not e[4] for e in ents)
            elif a == 'frenzy':               want = True
            if want:
                ab_cd = c['ab_cd']
                ab_uses += 1
                if c['ab_dur'] > 0:
                    ab_active = c['ab_dur']
                if a == 'shell':
                    shields += SHELL_CHARGES
                elif a == 'inkjet':
                    vx += INKJET_FWD; vy += INKJET_UP
                elif a == 'slam':
                    vy = -max(SLAM_DOWN, -vy); slam_armed = True
                elif a == 'swoop':
                    targets = [e for e in ents if 0 < e[0] - x < SWOOP_RANGE and e[1] - y > SWOOP_MIN_DY and not e[5] and not e[4]]
                    if targets:
                        tgt = min(targets, key=lambda e: (e[0] - x) ** 2 + (e[1] - y) ** 2)
                        dx, dy = tgt[0] - x, tgt[1] - y
                        length = math.hypot(dx, dy) or 1
                        sp = math.hypot(vx, vy) * SWOOP_KEEP
                        vx, vy = dx / length * sp, dy / length * sp

        # ---- rockets: fire near the apex
        if state == 'fly' and rockets > 0 and stun <= 0 and abs(vy) < 120 and vx > 0 and random.random() < player_skill:
            rockets -= 1
            vx += c['rocket_str']
            vy += c['rocket_str'] * 0.18

        diving = state == 'fly' and stun <= 0 and vy < -150 and random.random() < player_skill

        if state == 'fly':
            gm = DIVE_GRAV_MULT if diving else 1.0
            if floating > 0:
                gm *= BALLOON_G
            gm *= c['grav']
            drag_rate = c['drag']
            if ab_active > 0 and c['ability'] == 'tuck':
                drag_rate *= TUCK_DRAG_MULT
                vx += TUCK_PUSH * DT
            if ab_active > 0 and c['ability'] == 'glide':
                gm *= GLIDE_G_MULT
                vx += GLIDE_PUSH * DT
            vy += G * gm * DT
            vx += c['sail'] * DT
            if zone == 'jet':
                vx += JET_PUSH * DT; vy += JET_LIFT * DT
            elif zone == 'birds':
                vy += 380 * DT; vx += 120 * DT
            elif zone == 'cloud':
                if c['storm_forward']:
                    vx += 700 * DT
                else:
                    vy -= 700 * DT
            f = max(0.0, 1 - drag_rate * DT)
            if zone == 'whirl':
                vy -= WHIRL_PULL * DT
                f *= max(0.0, 1 - WHIRL_DRAG * DT)
            vx *= f; vy *= f
            prev_x = x
            x += vx * DT; y += vy * DT
            cur_flight += DT

            # walls: crossed one this step, at a height it actually occupies?
            for wobj in walls:
                wx, wh, wt, wbroken, wrejected = wobj
                if wbroken or not (prev_x < wx <= x) or y > wh or y < 0:
                    continue
                spd = math.hypot(vx, vy)
                if spd >= wt or shields > 0:
                    if spd < wt:
                        shields -= 1
                    wobj[3] = True
                    vx *= BARRIER_SMASH_KEEP
                    coins += pay(BARRIER_SMASH_COINS * max(1, int(wh / BARRIER_BLOCK)))
                    smashed += 1
                else:
                    vx *= BARRIER_BOUNCE_MULT
                    vy = min(vy, 0)
                    if not wrejected:          # only the first rejection costs hull
                        wobj[4] = True
                        hull -= BARRIER_DAMAGE * c['damage']
                    x = wx - BARRIER_BOUNCE_BACK
                break

            if y <= WATER_Y:
                ang_i = math.atan2(-vy, max(vx, 1))
                max_a = c['dive_max'] if diving else c['skip_max']
                spd = math.hypot(vx, vy)
                slammed = slam_armed
                slam_armed = False
                forced = slammed or (ab_active > 0 and c['ability'] == 'puff')
                natural = -vy > SKIP_MIN_VY and ang_i < max_a and vx > SKIP_MIN_VY
                if natural or (forced and vx > SKIP_MIN_VY):
                    rest = c['rest']
                    if diving: rest *= DIVE_REST_BONUS
                    if ab_active > 0 and c['ability'] == 'puff': rest *= PUFF_REST_MULT
                    if slammed: rest *= SLAM_REST_MULT
                    rest = min(rest, SKIP_REST_CEIL)
                    perfect = ang_i < PERFECT_ANGLE
                    bounce = -vy * rest
                    if forced and not natural:
                        bounce = max(bounce, FORCED_SKIP_MIN_BOUNCE)
                    vy = bounce
                    ret = c['retention'] * (PERFECT_SPEED_BONUS if perfect else 1.0)
                    if slammed: ret *= SLAM_FWD_BONUS
                    vx *= min(ret, SKIP_RET_CEIL)
                    y = WATER_Y
                    skips += 1; combo += 1; best_combo = max(best_combo, combo)
                    coins += pay(COMBO_COIN_STEP * combo)
                    if perfect:
                        perfects += 1
                        coins += pay(PERFECT_COINS)
                    if spd > c['hard_t']:
                        hull -= HARD_DMG_PER_100 * (spd - c['hard_t']) / 100 * c['damage']
                else:
                    state = 'plow'; y = WATER_Y; vy = 0; combo = 0
                    if spd > c['hard_t']:
                        hull -= HARD_DMG_PER_100 * (spd - c['hard_t']) / 100 * c['damage']
                max_flight = max(max_flight, cur_flight); cur_flight = 0
        else:
            vx *= math.exp(-c['plow'] * DT)
            if zone == 'whirl':
                vx *= math.exp(-WHIRL_DRAG * 3 * DT)
            x += vx * DT
            if vx < END_SPEED:
                break

        if hull <= 0:
            break

        # ---- entities
        zone = None
        frenzied = ab_active > 0 and c['ability'] == 'frenzy'
        for e in ents:
            ex, ey, er, k, is_h, used = e
            if used and k not in ZONES:
                continue
            # Coin Magnet drags nearby arc coins in.
            if k == 'coin' and not used and c['magnet'] > 0:
                if math.hypot(ex - x, ey - y) <= c['magnet']:
                    step = min(900 * DT, math.hypot(ex - x, ey - y))
                    d0 = math.hypot(ex - x, ey - y) or 1
                    e[0] += (x - ex) / d0 * step
                    e[1] += (y - ey) / d0 * step
                    ex, ey = e[0], e[1]
            if abs(ex - x) < er and abs(ey - y) < er:
                if k in ZONES:
                    zone = k
                    continue
                if is_h and shields > 0:      # Tock's shell soaks the whole hazard
                    shields -= 1
                    e[5] = True
                    continue
                e[5] = True
                if k == 'buoy':
                    if vy < 0 or state == 'plow':
                        vy = max(abs(vy) * 0.5, 0) + 520; state = 'fly'; y = WATER_Y + 1
                elif k == 'whale':
                    vy = 950; vx += 80; state = 'fly'; y = WATER_Y + 1
                elif k == 'motor':
                    vx += 480
                elif k == 'coins':
                    coins += pay(40)
                elif k == 'fuel':
                    coins += pay(25)
                elif k == 'coin':
                    coins += pay(COIN_VALUE)
                elif k == 'dolphin':
                    vy = max(vy, 0) * 0.3 + DOLPHIN_UP; vx += DOLPHIN_FWD; state = 'fly'; y = WATER_Y + 1
                elif k == 'crate':
                    vx *= CRATE_KEEP; coins += pay(CRATE_COINS)
                elif k == 'blimp':
                    vy = abs(vy) * BLIMP_KEEP + BLIMP_UP; vx += BLIMP_FWD; e[5] = False
                elif k == 'ring':
                    cur = math.hypot(vx, vy)
                    if cur > 1:
                        f2 = (cur + RING_SPEED) / cur
                        vx *= f2; vy *= f2
                    else:
                        vx += RING_SPEED
                    coins += pay(RING_COINS)
                elif k == 'balloon':
                    vy += BALLOON_LIFT; floating = BALLOON_SEC
                elif k == 'mine':
                    if not frenzied: vx *= MINE_SPEED
                    vy = max(vy, 0) + MINE_UP; hull -= MINE_DMG * c['damage']; hazards_hit += 1
                    state = 'fly'; y = WATER_Y + 1
                elif k == 'jelly':
                    if not frenzied: vy *= JELLY_VY
                    hull -= JELLY_DMG * c['damage']; stun = JELLY_STUN; hazards_hit += 1
                elif k == 'rock':
                    if not frenzied: vx *= 0.6
                    hull -= 25 * c['damage']; hazards_hit += 1
                elif k == 'net':
                    if not frenzied: vx *= 0.45; vy *= 0.5
                    hazards_hit += 1
                elif k == 'shark':
                    if not frenzied: vx *= 0.75
                    vy = max(vy, 0) + 200; hull -= 20 * c['damage']; hazards_hit += 1; state = 'fly'
        t += DT
        if t > 600:
            break

    dist_m = x / PPM
    coins += pay(int(dist_m))
    return dict(dist=dist_m, coins=coins, t=t, skips=skips, hull=hull, hits=hazards_hit,
                maxflight=max_flight, combo=best_combo, perfects=perfects, abilities=ab_uses,
                smashed=smashed, walls=len([w for w in walls if w[0] <= x]))


def batch(tiers, n=300, skill=0.6, label='', **kw):
    rs = [run(tiers, skill, **kw) for _ in range(n)]
    d = sorted(r['dist'] for r in rs)
    print(f"{label:30s} tiers={tiers} skill={skill}: median={statistics.median(d):6.0f}m  "
          f"p10={d[int(n*0.1)]:6.0f}  p90={d[int(n*0.9)]:6.0f}  "
          f"coins~{statistics.median(r['coins'] for r in rs):6.0f}  "
          f"skips~{statistics.mean(r['skips'] for r in rs):4.1f}  "
          f"combo~{statistics.mean(r['combo'] for r in rs):3.1f}  "
          f"perf~{statistics.mean(r['perfects'] for r in rs):3.1f}  "
          f"ab~{statistics.mean(r['abilities'] for r in rs):4.1f}  "
          f"smash~{statistics.mean(r['smashed'] for r in rs):4.1f}/{statistics.mean(r['walls'] for r in rs):4.1f}  "
          f"t~{statistics.mean(r['t'] for r in rs):4.1f}s sunk={sum(1 for r in rs if r['hull']<=0)}")
    return statistics.median(d)


if __name__ == '__main__':
    random.seed(7)
    print("=== Core progression (Marlow, cannon, no gear) " + "=" * 34)
    batch((0,0,0,0,0), skill=0.3, label='Run 1-3 (fresh, clumsy)')
    batch((0,0,0,0,0), skill=0.6, label='Fresh, decent')
    batch((1,0,0,0,0), skill=0.6, label='Launcher 1')
    batch((1,1,1,0,0), skill=0.6, label='L1 H1 R1')
    batch((2,1,1,1,1), skill=0.6, label='~Run 10 mid')
    batch((3,2,2,2,1), skill=0.6, label='Mid-late')
    batch((5,5,5,5,5), skill=0.6, label='Max, decent')
    batch((5,5,5,5,5), skill=0.9, label='Max, skilled')

    print()
    print("=== Riders (mid-late tiers, cannon, no gear) " + "=" * 36)
    for name in CREW:
        batch((3,2,2,2,1), skill=0.6, crew=name, label=f'{name} ({CREW[name][8]})')

    print()
    print("=== Gear, one part at a time (mid-late, Marlow) " + "=" * 33)
    batch((3,2,2,2,1), skill=0.6, label='no gear')
    for g in GEAR:
        batch((3,2,2,2,1), skill=0.6, gear=(g,), label=g)
    batch((3,2,2,2,1), skill=0.6, gear=('wheels','boxKite','luckyHorseshoe'), label='distance build')
    batch((3,2,2,2,1), skill=0.6, gear=('springKeel','jetVent','coinMagnet'), label='coin build')

    print()
    print("=== Launchers (mid-late, Marlow, no gear) " + "=" * 39)
    for lk in LAUNCHERS:
        batch((3,2,2,2,1), skill=0.6, launcher=lk, label=lk)
        batch((3,2,2,2,1), skill=0.9, launcher=lk, label=lk + ' (skilled)')

    print()
    print("=== Daily modifiers (mid-late, Marlow, no gear) " + "=" * 33)
    for dm in DAILY:
        batch((3,2,2,2,1), skill=0.6, daily=dm, label=dm)

    print()
    print("=== End game " + "=" * 68)
    batch((5,5,5,5,5), skill=0.9, crew='chum', gear=('wheels','boxKite','luckyHorseshoe'),
          launcher='torpedo', label='max + best distance build')
    batch((5,5,5,5,5), skill=0.9, crew='pip', gear=('springKeel','jetVent','coinMagnet'),
          prestige=3, launcher='rodReel', label='max + coin build + prestige 3')

    print()
    print("=== Coin economy: greedy buyer, 15 runs " + "=" * 41)
    PRICES = {'L':260,'H':200,'R':320,'A':360,'U':220}
    order = ['L','H','R','L','A','U','H','R','L','A','H','R','L','A','U','L','H','R','A','U','H','R','A','U','U']
    tiers = {'L':0,'H':0,'R':0,'A':0,'U':0}
    coins = 0; qi = 0
    for run_i in range(1, 16):
        r = run((tiers['L'],tiers['H'],tiers['R'],tiers['A'],tiers['U']), 0.5)
        coins += r['coins']
        bought = []
        while qi < len(order):
            k = order[qi]; price = int(PRICES[k]*2.2**tiers[k])
            if coins >= price and tiers[k] < 5:
                coins -= price; tiers[k]+=1; bought.append(f"{k}{tiers[k]}({price})"); qi += 1
            else: break
        print(f"run {run_i:2d}: {r['dist']:5.0f}m  coins after shop={coins:6d}  tiers={tiers}  bought={bought}")

    print()
    print("=== Locker affordability: runs of saving per unlock " + "=" * 26)
    # The locker is the long tail *after* the five shop tracks max out, so nothing here
    # should be affordable in a run or two at the tier you first want it.
    rates = {}
    for label, t in [('early', (1,1,1,0,0)), ('mid', (2,1,1,1,1)),
                     ('mid-late', (3,2,2,2,1)), ('max', (5,5,5,5,5))]:
        rates[label] = statistics.median(run(t, 0.6)['coins'] for _ in range(80))
        print(f"  coins/run at {label:9s} tiers {t}: {rates[label]:6.0f}")
    print()
    LOCKER = [
        ('Bristle', 2_500, 'early'), ('Beach Wheels', 3_000, 'early'),
        ('Coin Magnet', 3_500, 'mid'), ('Pontoons', 4_500, 'mid'), ('Bruno', 5_500, 'mid'),
        ('Storm Sail', 6_000, 'mid-late'), ('Barnacle Plating', 7_000, 'mid-late'),
        ('Pip', 8_000, 'mid-late'), ('Box Kite', 9_000, 'mid-late'),
        ('Spring Keel', 11_000, 'mid-late'), ('Tock', 11_000, 'mid-late'),
        ('Lucky Horseshoe', 13_000, 'mid-late'), ('Jet Vent', 16_000, 'mid-late'),
        ('Chum', 17_000, 'mid-late'), ('Rod & Reel', 22_000, 'mid-late'),
        ('Gilly', 24_000, 'max'), ('Nixie', 32_000, 'max'),
        ('Tidal Slingshot', 40_000, 'max'), ('Torpedo Tube', 65_000, 'max'),
    ]
    total = 0
    for name, price, stage in LOCKER:
        total += price
        print(f"  {name:18s} {price:6,d}  ->  {price / rates[stage]:5.1f} runs at the {stage} rate")
    print(f"\n  whole locker: {total:,} coins (missions, trophies and the daily pay on top)")
