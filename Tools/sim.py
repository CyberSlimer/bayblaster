"""Pacing simulation mirroring Constants.swift + WaterSkipSystem + WorldSpawner.
Run: python sim.py
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

BOOSTS = {
    'buoy':    dict(w=30, y=(0, 0), r=28,  ),
    'whale':   dict(w=12, y=(0, 0), r=40),
    'motor':   dict(w=18, y=(40, 260), r=26),
    'birds':   dict(w=15, y=(300, 900), r=120),
    'coins':   dict(w=15, y=(60, 500), r=24),
    'fuel':    dict(w=10, y=(30, 300), r=24),
    'dolphin': dict(w=14, y=(0, 0), r=38),
    'balloon': dict(w=12, y=(200, 650), r=34),
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
ZONES = {'birds', 'cloud', 'whirl'}

def pick(table):
    tot = sum(v['w'] for v in table.values())
    r = random.random()*tot
    for k, v in table.items():
        r -= v['w']
        if r <= 0: return k
    return k

def run(tiers, player_skill=0.6, verbose=False):
    L, H, R, A, U = tiers
    v = LAUNCH_SPEED[L]
    ang = math.radians(random.uniform(38, 52))   # decent player aims ~45
    power = random.uniform(0.75, 1.0)             # meter lock quality
    vx, vy = v*power*math.cos(ang), v*power*math.sin(ang)
    x, y = 0.0, 60.0
    hull = HULL_MAX[H]
    rockets = ROCKET_COUNT[R]
    drag = AIR_DRAG[A]
    boost_mult = LURE_BOOST[U]
    coins = 0
    state = 'fly'
    t = 0.0
    diving = False
    next_spawn = 400.0
    ents = []
    skips = 0
    hazards_hit = 0
    zone = None
    flight_time = 0
    max_flight = 0
    cur_flight = 0
    combo = 0
    best_combo = 0
    perfects = 0
    stun = 0.0
    floating = 0.0
    last_water_haz = False
    while True:
        # spawn ahead
        while next_spawn < x + 6000:
            d_m = next_spawn/PPM
            haz_frac = BASE_HAZ_FRAC + (HAZ_FRAC_AT_5000-BASE_HAZ_FRAC)*min(1, d_m/5000)
            if last_water_haz: haz_frac *= HAZ_REPEAT_PENALTY
            # lure increases boost share
            bw = (1-haz_frac)*boost_mult
            density = 1.0 + min(1.0, d_m/4000)*0.6
            if random.random() < bw/(bw+haz_frac):
                if random.random() < COIN_ARC_CHANCE:
                    n = random.randint(*COIN_ARC_COUNT)
                    peak = random.uniform(*COIN_ARC_HEIGHT)
                    rise = COIN_ARC_RISE*random.uniform(0.5, 1.2)
                    for i in range(n):
                        u = i/max(n-1, 1); curve = 1-((u-0.5)*2)**2
                        ents.append([next_spawn + i*COIN_ARC_SPACING, max(peak-rise+rise*curve, 30), 20, 'coin', False, False])
                    next_spawn += n*COIN_ARC_SPACING
                    last_water_haz = False
                    next_spawn += random.uniform(*SPAWN_INTERVAL_M)*PPM/density
                    continue
                k = pick(BOOSTS); spec = BOOSTS[k]; is_h = False
            else:
                k = pick(HAZ); spec = HAZ[k]; is_h = True
            last_water_haz = k in WATER_HAZ
            ey = random.uniform(*spec['y'])
            ents.append([next_spawn, ey, spec['r'], k, is_h, False])
            next_spawn += random.uniform(*SPAWN_INTERVAL_M)*PPM/density
        stun = max(0.0, stun-DT); floating = max(0.0, floating-DT)
        # rocket usage: fire when airborne and rising slowly / at apex
        if state == 'fly' and rockets > 0 and stun <= 0 and abs(vy) < 120 and vx > 0 and random.random() < player_skill:
            rockets -= 1
            vx += ROCKET_STR[R]
            vy += ROCKET_STR[R]*0.18
        # dive: skilled player dives on descent
        diving = state == 'fly' and stun <= 0 and vy < -150 and random.random() < player_skill
        if state == 'fly':
            gm = DIVE_GRAV_MULT if diving else 1.0
            if floating > 0: gm *= BALLOON_G
            vy += G*gm*DT
            # zone effects
            if zone == 'birds': vy += 380*DT; vx += 120*DT
            elif zone == 'cloud': vy -= 700*DT
            f = max(0.0, 1 - drag*DT)
            if zone == 'whirl':
                vy -= WHIRL_PULL*DT
                f *= max(0.0, 1 - WHIRL_DRAG*DT)
            vx *= f; vy *= f
            x += vx*DT; y += vy*DT
            cur_flight += DT
            if y <= WATER_Y:
                ang_i = math.atan2(-vy, max(vx, 1))
                max_a = DIVE_MAX_ANGLE if diving else SKIP_MAX_ANGLE
                spd = math.hypot(vx, vy)
                if -vy > SKIP_MIN_VY and ang_i < max_a and vx > END_SPEED*2:
                    rest = SKIP_V_REST*(DIVE_REST_BONUS if diving else 1.0)
                    perfect = ang_i < PERFECT_ANGLE
                    vy = -vy*rest
                    vx *= SKIP_H_RET[H]*(PERFECT_SPEED_BONUS if perfect else 1.0)
                    y = WATER_Y
                    skips += 1; combo += 1; best_combo = max(best_combo, combo)
                    coins += COMBO_COIN_STEP*combo
                    if perfect: perfects += 1; coins += PERFECT_COINS
                    if spd > HARD_IMPACT_T[H]:
                        hull -= HARD_DMG_PER_100*(spd-HARD_IMPACT_T[H])/100
                else:
                    state = 'plow'; y = WATER_Y; vy = 0; combo = 0
                    if spd > HARD_IMPACT_T[H]:
                        hull -= HARD_DMG_PER_100*(spd-HARD_IMPACT_T[H])/100
                max_flight = max(max_flight, cur_flight); cur_flight = 0
        else:
            vx *= math.exp(-PLOW_DRAG*DT)
            if zone == 'whirl': vx *= math.exp(-WHIRL_DRAG*3*DT)
            x += vx*DT
            if vx < END_SPEED: break
        if hull <= 0: break
        # entities
        zone = None
        for e in ents:
            ex, ey, er, k, is_h, used = e
            if used and k not in ZONES: continue
            if abs(ex-x) < er and abs(ey-y) < er:
                if k in ZONES:
                    zone = k; continue
                e[5] = True
                if k == 'buoy':
                    if vy < 0 or state == 'plow':
                        vy = max(abs(vy)*0.5, 0) + 520; state = 'fly'; y = WATER_Y+1
                elif k == 'whale':
                    vy = 950; vx += 80; state = 'fly'; y = WATER_Y+1
                elif k == 'motor':
                    vx += 480
                elif k == 'coins':
                    coins += 40
                elif k == 'fuel':
                    coins += 25
                elif k == 'coin':
                    coins += COIN_VALUE
                elif k == 'dolphin':
                    vy = max(vy, 0)*0.3 + DOLPHIN_UP; vx += DOLPHIN_FWD; state = 'fly'; y = WATER_Y+1
                elif k == 'balloon':
                    vy += BALLOON_LIFT; floating = BALLOON_SEC
                elif k == 'mine':
                    vx *= MINE_SPEED; vy = max(vy, 0) + MINE_UP; hull -= MINE_DMG; hazards_hit += 1; state = 'fly'; y = WATER_Y+1
                elif k == 'jelly':
                    vy *= JELLY_VY; hull -= JELLY_DMG; stun = JELLY_STUN; hazards_hit += 1
                elif k == 'rock':
                    vx *= 0.6; hull -= 25; hazards_hit += 1
                elif k == 'net':
                    vx *= 0.45; vy *= 0.5; hazards_hit += 1
                elif k == 'shark':
                    vx *= 0.75; vy = max(vy, 0) + 200; hull -= 20; hazards_hit += 1; state = 'fly'
        t += DT
        if t > 600: break
    dist_m = x/PPM
    coins += int(dist_m)
    return dict(dist=dist_m, coins=coins, t=t, skips=skips, hull=hull, hits=hazards_hit, maxflight=max_flight,
                combo=best_combo, perfects=perfects)

def batch(tiers, n=300, skill=0.6, label=''):
    rs = [run(tiers, skill) for _ in range(n)]
    d = [r['dist'] for r in rs]
    d.sort()
    print(f"{label:28s} tiers={tiers} skill={skill}: median={statistics.median(d):6.0f}m  p10={d[int(n*0.1)]:6.0f}  p90={d[int(n*0.9)]:6.0f}  "
          f"coins~{statistics.median(r['coins'] for r in rs):5.0f}  skips~{statistics.mean(r['skips'] for r in rs):4.1f}  combo~{statistics.mean(r['combo'] for r in rs):3.1f}  "
          f"perf~{statistics.mean(r['perfects'] for r in rs):3.1f}  t~{statistics.mean(r['t'] for r in rs):4.1f}s sunk={sum(1 for r in rs if r['hull']<=0)}")
    return statistics.median(d)

if __name__ == '__main__':
    random.seed(7)
    batch((0,0,0,0,0), skill=0.3, label='Run 1-3 (fresh, clumsy)')
    batch((0,0,0,0,0), skill=0.6, label='Fresh, decent')
    batch((1,0,0,0,0), skill=0.6, label='Launcher 1')
    batch((1,1,1,0,0), skill=0.6, label='L1 H1 R1')
    batch((2,1,1,1,1), skill=0.6, label='~Run 10 mid')
    batch((3,2,2,2,1), skill=0.6, label='Mid-late')
    batch((5,5,5,5,5), skill=0.6, label='Max, decent')
    batch((5,5,5,5,5), skill=0.9, label='Max, skilled')
    # economy: greedy buy cheapest-useful upgrade after each run
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
        print(f"run {run_i:2d}: {r['dist']:5.0f}m  coins after shop={coins:5d}  tiers={tiers}  bought={bought}")

