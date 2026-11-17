#!/usr/bin/env python3
"""Generates the announcer's voice lines with ElevenLabs (pure Python).

Clips are created once and bundled into the app (assets/voice/), so the app
plays them offline with no per-use cost. Re-running only generates clips
whose text, voice or model changed (cached in assets/voice/manifest.json).

Setup: put ELEVENLABS_API_KEY=... in .env at the project root (git-ignored).

    python3 tool/generate_voice.py --dry-run          # show cost, spend nothing
    python3 tool/generate_voice.py                    # generic lines
    python3 tool/generate_voice.py --players "Jay Park=J-Splash, Danny Kim"
    python3 tool/generate_voice.py --backup nong9live-backup.json   # whole roster
    python3 tool/generate_voice.py --voice <voice_id> --force       # new voice

Player lines use the nickname if given (after "="), else the first name.
Cost: about 1 ElevenLabs credit per character (tags like [excited] count).
"""

import argparse
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..'))
OUT = os.path.join(ROOT, 'assets', 'voice')
MANIFEST = os.path.join(OUT, 'manifest.json')

DEFAULT_VOICE = 'pNInz6obpgDQGcFmaJgB'  # "Adam" (built-in, free-plan API OK)
DEFAULT_MODEL = 'eleven_v3'  # supports [excited] / [shouting] audio tags

# key -> variants. Keys are what the app asks for (see lib/services/voice_pack.dart).
LINES = {
    'three': [
        '[excited] BANG! From downtown!',
        '[shouting] Splash! He drains the three!',
        '[excited] From WAY downtown... BANG!',
        '[excited] Three ball... GOOD! Cash money!',
    ],
    'deep': [
        '[excited] From deep... BANG!',
        '[shouting] Splash! Wet from way out!',
    ],
    'bucket': [
        '[excited] Bucket!',
        'Count it!',
        '[excited] And he finishes!',
        'Too easy.',
    ],
    'ft': ['Free throw is good.', 'Knocks down the freebie.'],
    'brick': ['[laughs] Brick!', 'Clank! Off the iron.'],
    'airball': [
        '[shouting] AIR BALL!',
        '[laughs] Ohhh, air ball!',
        '[sarcastic] That one hit nothing but air.',
    ],
    'block': [
        '[shouting] REJECTED!',
        '[excited] Get that outta here!',
        '[shouting] Not in my house!',
        '[excited] Sent back with authority!',
    ],
    'steal': ['[excited] Picked his pocket!', "[excited] Stolen! And he's gone!"],
    'foul': ["Whistle! That's a foul.", 'Foul on the play.'],
    'travel': ['Traveling!', "[laughs] That's a walk!"],
    'turnover': ['Turnover.', '[excited] Coughs it up!'],
    'timeout': ['Timeout on the floor.'],
    'tipoff': [
        '[excited] Here we go! Ball is up!',
        "[excited] Tip-off! Let's get it!",
        "[excited] Alright, let's run it!",
    ],
    'gamepoint': ['[excited] Game point!', '[excited] Next bucket wins it!'],
    'gameover': [
        "[shouting] That's the ballgame!",
        '[excited] Game over! What a run!',
        'And that... is the ballgame!',
    ],
    'hype': [
        '[shouting] Oh my goodness!',
        '[shouting] Are you kidding me?!',
        "[excited] He's on fire!",
    ],
    # Ref-mode quick phrases
    'and_one': ['[shouting] And one!'],
    'ball_dont_lie': ["[laughs] Ball don't lie!"],
    'check_ball': ['Check ball.'],
    'next': ['Next!'],
    'run_it_back': ['[excited] Run it back!'],
    'whos_next': ["Who's got next?"],
    'defense': ['[shouting] Defense! Defense!'],
    'ice_cold': ['Ice cold.'],
}

# Team shirt colors offered by the app (lib/models/game.dart teamColorPresets).
TEAM_COLORS = ['White', 'Black', 'Red', 'Blue', 'Green', 'Yellow', 'Orange', 'Purple', 'Gray', 'Navy']
for c in TEAM_COLORS:
    LINES[f'win_{c.lower()}'] = [f'[excited] {c} wins it!']
    LINES[f'gamepoint_{c.lower()}'] = [f'[excited] Game point, {c}!']

PLAYER_LINES = {
    'three': ['[excited] {n} for three!', '[shouting] {n}... BANG!'],
    'bucket': ['[excited] {n} scores!'],
    'block': ['[shouting] {n} with the rejection!'],
    'steal': ['[excited] {n} with the steal!'],
    'airball': ['[laughs] Air ball, {n}!'],
    'foul': ['Foul on {n}.'],
}


def norm_name(s):
    return re.sub(r'\s+', ' ', s.strip().lower())


def slug(s):
    return re.sub(r'[^a-z0-9]+', '_', s.lower()).strip('_') or 'player'


def load_key():
    key = os.environ.get('ELEVENLABS_API_KEY')
    env = os.path.join(ROOT, '.env')
    if not key and os.path.exists(env):
        for line in open(env):
            if line.strip().startswith('ELEVENLABS_API_KEY='):
                key = line.split('=', 1)[1].strip().strip('"').strip("'")
    if not key:
        sys.exit('No ELEVENLABS_API_KEY in environment or .env')
    return key


def parse_players(args):
    """Returns [(name, spoken)]."""
    out = []
    if args.players:
        for part in args.players.split(','):
            if not part.strip():
                continue
            name, _, nick = part.partition('=')
            name = name.strip()
            out.append((name, nick.strip() or name.split()[0]))
    if args.backup:
        data = json.load(open(args.backup))
        for p in data.get('players', []):
            if p.get('archived'):
                continue
            name = p['name'].strip()
            out.append((name, (p.get('nickname') or '').strip() or name.split()[0]))
    return out


def tts(key, voice, model, text):
    body = json.dumps({'text': text, 'model_id': model}).encode()
    url = f'https://api.elevenlabs.io/v1/text-to-speech/{voice}?output_format=mp3_44100_128'
    for attempt in range(5):
        req = urllib.request.Request(url, data=body, method='POST',
                                     headers={'xi-api-key': key, 'Content-Type': 'application/json'})
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return r.read(), int(r.headers.get('character-cost') or len(text))
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors='replace')[:300]
            if e.code in (429, 500, 502, 503) and attempt < 4:
                time.sleep(2 * (attempt + 1))
                continue
            sys.exit(f'ElevenLabs error {e.code}: {detail}')
    sys.exit('Gave up after retries')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--voice', default=None, help='voice id (default: keep current or Adam)')
    ap.add_argument('--model', default=None)
    ap.add_argument('--players', help='"Full Name=Nickname, Other Name"')
    ap.add_argument('--backup', help='path to an app backup .json to read the roster from')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--force', action='store_true', help='regenerate everything')
    args = ap.parse_args()

    manifest = json.load(open(MANIFEST)) if os.path.exists(MANIFEST) else {}
    voice = args.voice or manifest.get('voiceId') or DEFAULT_VOICE
    model = args.model or manifest.get('model') or DEFAULT_MODEL
    cache = {} if args.force else manifest.get('cache', {})

    jobs = []  # (section, owner, key, index, text, filename)
    for k, variants in LINES.items():
        for i, text in enumerate(variants):
            jobs.append(('lines', None, k, i, text, f'{k}_{i + 1}.mp3'))
    players = {norm_name(n): s for n, s in manifest.get('roster', {}).items()}
    for name, spoken in parse_players(args):
        players[norm_name(name)] = spoken
    for name, spoken in players.items():
        for k, templates in PLAYER_LINES.items():
            for i, t in enumerate(templates):
                jobs.append(('players', name, k, i, t.format(n=spoken), f'p_{slug(name)}_{k}_{i + 1}.mp3'))

    def fingerprint(text):
        return hashlib.sha1(f'{voice}|{model}|{text}'.encode()).hexdigest()[:16]

    todo = [j for j in jobs
            if cache.get(j[5]) != fingerprint(j[4]) or not os.path.exists(os.path.join(OUT, j[5]))]
    cost = sum(len(j[4]) for j in todo)
    print(f'voice={voice} model={model}: {len(jobs)} clips, {len(todo)} to generate, ~{cost} credits')
    if args.dry_run or not todo:
        if not todo:
            print('Everything is up to date.')
        return

    os.makedirs(OUT, exist_ok=True)
    spent = 0
    for n, (_, _, _, _, text, fname) in enumerate(todo, 1):
        audio, c = tts(load_key(), voice, model, text)
        with open(os.path.join(OUT, fname), 'wb') as f:
            f.write(audio)
        cache[fname] = fingerprint(text)
        spent += c
        print(f'  [{n}/{len(todo)}] {fname:34} {c:3} cr  {text}')

    lines, pmap = {}, {}
    for section, owner, k, _, _, fname in jobs:
        if section == 'lines':
            lines.setdefault(k, []).append(fname)
        else:
            pmap.setdefault(owner, {}).setdefault(k, []).append(fname)
    known = {f for _, _, _, _, _, f in jobs}
    for f in os.listdir(OUT):  # drop clips that are no longer in the catalog
        if f.endswith('.mp3') and f not in known:
            os.remove(os.path.join(OUT, f))
            cache.pop(f, None)
    json.dump({
        'voiceId': voice,
        'model': model,
        'credit': 'Announcer voice generated with ElevenLabs',
        'lines': lines,
        'players': pmap,
        'roster': players,
        'cache': {k: v for k, v in cache.items() if k in known},
    }, open(MANIFEST, 'w'), indent=1, sort_keys=True)
    print(f'Done: {spent} credits spent. Manifest: {os.path.relpath(MANIFEST, ROOT)}')


if __name__ == '__main__':
    main()
