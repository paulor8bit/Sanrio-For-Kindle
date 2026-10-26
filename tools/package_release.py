"""Empacota a edição KOReader e as artes individuais."""
from pathlib import Path
import argparse
import hashlib
import zipfile

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--deps',type=Path,required=True,help='Fontes fixadas de FBInk e Lua')
args=parser.parse_args()
OUT=ROOT/'dist'
OUT.mkdir(exist_ok=True)

def archive(name, files):
    target=OUT/name
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as z:
        for path,destination in sorted(files):
            if path.is_file() and '__pycache__' not in path.parts:
                info=zipfile.ZipInfo(destination,(2026,10,26,0,0,0))
                info.create_system=3
                info.external_attr=(0o100755 if path.suffix=='.sh' or path.name=='sanriokindle' else 0o100644)<<16
                z.writestr(info,path.read_bytes(),compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
    with zipfile.ZipFile(target) as z:
        assert z.testzip() is None
    print(f'{name}: {target.stat().st_size:,} bytes')
    return target

plugin=ROOT/'sanriokindle.koplugin'
game=archive('SanrioKindle-v0.1.0-koreader.zip',[(p,'koreader/plugins/sanriokindle.koplugin/'+p.relative_to(plugin).as_posix()) for p in plugin.rglob('*')])
art=archive('SanrioKindle-v0.1.0-artes.zip',[(p,'artes/'+p.relative_to(ROOT/'artes').as_posix()) for p in (ROOT/'artes').rglob('*')])
prefix='extensions/sanriokindle/'
native=ROOT/'native'
binary=native/'build/sanriokindle'
assert binary.is_file(),'Compile a edição KUAL primeiro'
elf=binary.read_bytes()
assert elf[:4]==b'\x7fELF' and int.from_bytes(elf[18:20],'little')==40,'Executável deve ser ARM ELF'
entries=[(binary,prefix+'sanriokindle'),(native/'runtime.lua',prefix+'runtime.lua'),(native/'LICENSE-GPL-3.0.txt',prefix+'LICENSE-GPL-3.0.txt'),(native/'README.md',prefix+'BUILD-AND-SOURCE.md')]
for folder in ['fonts','licenses','kual']:
    entries += [(p,prefix+('' if folder=='kual' else folder+'/')+p.relative_to(native/folder).as_posix()) for p in (native/folder).rglob('*')]
entries += [(p,prefix+'game/'+p.relative_to(plugin).as_posix()) for p in plugin.rglob('*')]
kual=archive('SanrioKindle-v0.1.0-kual.zip',entries)
source_files=[]
for p in ROOT.rglob('*'):
    rel=p.relative_to(ROOT)
    if any(part.startswith('.') or part=='__pycache__' for part in rel.parts):continue
    if rel.as_posix().startswith(('dist/','native/build/','tests/rendered/')):continue
    if p.suffix in {'.pyc','.dat','.old','.tmp','.log','.exe','.pgm'}:continue
    source_files.append((p,'Sanrio-For-Kindle/'+rel.as_posix()))
from build_native import SOURCES
for dependency in SOURCES:
    dep=args.deps.resolve()/dependency
    assert dep.is_dir(),dep
    for p in dep.rglob('*'):
        rel=p.relative_to(dep)
        if any(part.startswith('.') for part in rel.parts):continue
        source_files.append((p,'dependencies/'+dependency+'/'+rel.as_posix()))
source=archive('SanrioKindle-v0.1.0-fontes.zip',source_files)
with zipfile.ZipFile(source,'a',zipfile.ZIP_DEFLATED) as z:
    for dependency,(_,revision) in SOURCES.items():
        z.writestr('dependencies/'+dependency+'/POKEPAL_REVISION.txt',revision+'\n')
with zipfile.ZipFile(source) as z:
    assert z.testzip() is None
(OUT/'SHA256.txt').write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n' for p in [game,kual,art,source]))
with zipfile.ZipFile(kual) as z:
    assert z.getinfo(prefix+'sanriokindle').external_attr>>16 & 0o111
    assert not any(n.endswith(('.dat','.old','.log','.exe','.pgm')) for n in z.namelist())
