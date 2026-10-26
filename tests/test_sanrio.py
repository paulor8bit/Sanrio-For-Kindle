"""Validação dos quatro personagens, progressão, salvamento e telas reais Lua."""
import io
import json
from pathlib import Path
from PIL import Image
import render_harness as h

root=Path(__file__).resolve().parents[1]
plugin=root/'sanriokindle.koplugin'
lua=h.lua; g=h.g
for path in plugin.rglob('*.lua'):
    lua.execute('assert(loadfile(...))',path.as_posix())
index=json.loads((plugin/'assets/sprite-index.json').read_text())
assert len(index)==88
for name,(ident,offset,length) in index.items():
    raw=(plugin/f'assets/{ident:03}.bin').read_bytes()[offset:offset+length]
    im=Image.open(io.BytesIO(raw)); assert im.size==(64,64)
    assert im.mode=='LA' and set(im.getchannel('L').getdata()) <= {0,85,170,255}
    bounds=im.getchannel('A').getbbox(); assert bounds and bounds[3]<=62
lua.execute('''
local now=os.time()
assert(#E.species==4 and #E.starters==4)
local expected={"Hello Kitty","Cinnamoroll","Kuromi","My Melody"}
local S=dofile(BASE..'/storage.lua');local R=dofile(BASE..'/reading.lua')
for id=1,4 do
 local s=E.new(now);E.act(s,'choose',id,now)
 assert(s.species==id and E.name(id)==expected[id] and E.valid(s))
 assert(#E.evolutionChoices(id)==0 and not E.ready(s))
 local berries=s.berries;E.act(s,'feed',nil,now);assert(s.berries==berries-1)
 R.init(s);E.act(s,'egg',nil,now);assert(s.egg and s.egg.id>=1 and s.egg.id<=4)
 E.readingReward(s,7200,now);assert(E.eggLeft(s)==0)
 local friend=s.egg.id;E.act(s,'hatch',nil,now);assert(not s.egg and s.seen[tostring(friend)])
 assert(E.valid(s));local restored=S.decode(S.encode(s),E);assert(restored and restored.species==id)
 for _,route in ipairs(E.routes) do assert(#route.pool>0);for _,v in ipairs(route.pool) do assert(E.species[v]) end end
 for route=1,3 do
  local t=E.new(now);E.act(t,'choose',id,now);E.act(t,'trip',route,now)
  assert(t.trip==route);E.act(t,'collect',nil,now+E.routes[route].seconds+1)
  assert(t.trip==0 and E.valid(t))
 end
end
local s=E.new(now);E.act(s,'choose',1,now)
for id=1,4 do s.seen[tostring(id)]=true end
E.badges(s,now);assert(s.badges['Sanrio friends'] and s.badges['Field researcher'])
print('PASS: personagens, alimentação, presentes, leitura, três passeios, conquistas e salvamento')
''')

screens=['home','profile','allcompanions','journal','explore','egg','more','preferences','sleeppreview','filters','snacks','reading','weekly','backgrounds','decorations','badges','memories','nickname','train','help','companions']
rendered=0; truncations=[]
for ident in range(1,5):
    for screen in screens:
        h.start();lua.execute('v=newView(...);v.screen=select(2,...);v.page=1',ident,screen)
        # Presentes também precisam aparecer corretamente na tela de descanso.
        lua.execute("dofile(BASE..'/reading.lua').init(v.state);E.act(v.state,'egg',nil,os.time())")
        lua.execute('v:paintTo(bb,0,0)')
        assert not h.bounds,(ident,screen,h.bounds)
        for text in h.painted_text:
            assert not any(word in text for word in ['Pokémon','POKEPAL','PokeK','npresente','of the way','160','151 Kanto']),text
        truncations += [(ident,screen,t) for t in h.truncated]
        if screen in ['home','sleeppreview','allcompanions']:
            h.canvas.save(root/f'docs/{ident}-{screen}.png')
        rendered+=1
for width,height in [(1072,1448),(800,600)]:
    for ident in range(1,5):
        h.start(width,height);lua.execute('v=newView(...);v:paintTo(bb,0,0)',ident)
        assert not h.bounds; rendered+=1
# Animações permanecem curtas para evitar atualizações contínuas no e-ink.
h.start();lua.execute('''
v=newView(1);v.state.animation='gentle';v:animate('play');assert(U:drain()<=5)
v.state.animation='eco';v:animate('feed');assert(U:drain()<=3)
v.state.animation='off';v:animate('play');assert(#U.queue==0)
''')
print(f'PASS: 88 referências de sprites, sintaxe Lua e {rendered} telas renderizadas')
print('Textos truncados:',truncations)
assert not truncations,truncations
# Comparação visual das quatro telas de jogo, renderizadas pelo próprio view.lua.
montage=Image.new('RGB',(1200,1600),'white')
for i in range(4): montage.paste(Image.open(root/f'docs/{i+1}-home.png').convert('RGB'),((i%2)*600,(i//2)*800))
montage.save(root/'docs/previa-jogo.png')
