"""Recorta cartelas originais e empacota quadros compatíveis com o PokeK."""
from pathlib import Path
import io
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'sanriokindle.koplugin/assets'
CHARACTERS = ['hello-kitty', 'cinnamoroll', 'kuromi', 'my-melody']
NAMES = ['Hello Kitty', 'Cinnamoroll', 'Kuromi', 'My Melody']
POSES = [('idle', 4), ('walk', 4), ('attack', 4), ('eat', 4), ('sleep', 2)]
# Separadores conferidos visualmente: a geração não produz linhas equidistantes.
ROW_CUTS = {
    'hello-kitty': [0,270,517,765,1025,1254],
    'cinnamoroll': [0,290,520,770,1010,1254],
    'kuromi': [0,264,505,755,1020,1254],
    'my-melody': [0,279,527,782,1040,1254],
}

def main():
    index, manifest = {}, {}
    preview = Image.new('RGB', (1200, 750), 'white')
    draw = ImageDraw.Draw(preview)
    font_path = 'C:/Windows/Fonts/arial.ttf' if Path('C:/Windows/Fonts/arial.ttf').exists() else '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
    bold_path = 'C:/Windows/Fonts/arialbd.ttf' if Path('C:/Windows/Fonts/arialbd.ttf').exists() else '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
    font = ImageFont.truetype(font_path, 20)
    title = ImageFont.truetype(bold_path, 29)
    draw.text((32, 20), 'SanrioKindle • Amigos de leitura', font=title, fill='black')
    draw.text((32, 60), 'Pixel art em tons de cinza • 4 personagens • 72 quadros de animação', font=font, fill='#555555')
    for ident, slug in enumerate(CHARACTERS, 1):
        source = Image.open(ROOT / f'artes/originais/{slug}.png').convert('RGBA')
        assert source.getchannel('A').getextrema()[0] == 0, 'Original sem transparência'
        cells = []
        for row, (pose, count) in enumerate(POSES):
            for col in range(count):
                box = (round(col*source.width/4), round(ROW_CUTS[slug][row]*source.height/1254),
                       round((col+1)*source.width/4), round(ROW_CUTS[slug][row+1]*source.height/1254))
                cell = source.crop(box)
                # Ruído semitransparente da geração não define o tamanho do personagem.
                bounds = cell.getchannel('A').point(lambda a: 255 if a >= 200 else 0).getbbox()
                assert bounds, (slug, pose, col)
                cells.append((pose, col+1, cell, bounds))
        # Um único fator de escala por personagem mantém a altura entre quadros.
        factor = min(56/max(b[2]-b[0] for _,_,_,b in cells),
                     57/max(b[3]-b[1] for _,_,_,b in cells))
        data, offsets = bytearray(), {}
        manifest[slug] = {'id': ident, 'nome': NAMES[ident-1], 'quadros': []}
        for pose, frame, cell, bounds in cells:
            crop = cell.crop(bounds)
            size = (max(1, round(crop.width*factor)), max(1, round(crop.height*factor)))
            # Apenas conversão técnica: paleta e grade de pixels para o Kindle.
            crop = crop.resize(size, Image.Resampling.NEAREST)
            gray = crop.convert('L').point(lambda p: min(255, round(p/85)*85))
            alpha = crop.getchannel('A').point(lambda a: 255 if a >= 128 else 0)
            sprite = Image.merge('LA', (gray, alpha))
            canvas = Image.new('LA', (64,64), (255,0))
            canvas.paste(sprite, ((64-size[0])//2, 61-size[1]))
            target = ROOT / f'artes/sprites/{slug}'
            target.mkdir(exist_ok=True)
            display_pose = 'brincar' if pose == 'attack' else {'idle':'repouso','walk':'caminhar','eat':'comer','sleep':'dormir'}[pose]
            canvas.save(target / f'{display_pose}-{frame}.png')
            stream = io.BytesIO(); canvas.save(stream, format='PNG'); content = stream.getvalue()
            offset = offsets.get(content)
            if offset is None:
                offset = len(data); offsets[content] = offset; data.extend(content)
            names = [f'{ident}-{pose}-{frame}.png']
            if pose == 'idle': names.append(f'{ident}-{frame}.png')
            for name in names: index[name] = [ident,offset,len(content)]
            manifest[slug]['quadros'].append({'pose':display_pose,'quadro':frame,'arquivo':f'sprites/{slug}/{display_pose}-{frame}.png'})
            if frame == 1:
                row = ident-1; col = [p for p,_ in POSES].index(pose)
                x, y = 195+col*195, 126+row*149
                enlarged = canvas.convert('RGBA').resize((128,128),Image.Resampling.NEAREST)
                preview.paste(enlarged,(x,y),enlarged)
                if ident == 1: draw.text((x,100),display_pose.capitalize(),font=font,fill='#555555')
        (ASSETS / f'{ident:03}.bin').write_bytes(data)
        draw.text((32,177+(ident-1)*149),NAMES[ident-1],font=font,fill='black')
    (ROOT / 'artes/catalogo.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2),encoding='utf-8')
    preview.save(ROOT / 'artes/previa-personagens.png')
    (ASSETS / 'sprite-index.json').write_text(json.dumps(index,sort_keys=True),encoding='utf-8')
    lines = ['local S={index={'] + [f' ["{name}"]={{{r[0]},{r[1]},{r[2]}}},' for name,r in sorted(index.items())]
    lines += ['}}', '''function S.read(directory,name)
 local r=assert(S.index[name],"Sprite desconhecido: "..name)
 local f=assert(io.open(directory..string.format("/%03d.bin",r[1]),"rb"))
 assert(f:seek("set",r[2]));local data=f:read(r[3]);f:close()
 assert(data and #data==r[3],"Pacote de sprites incompleto: "..name)
 return data
end
return S''']
    (ASSETS / 'sprites.lua').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    (ASSETS / 'frames.lua').write_text('return {[1]=4,[2]=4,[3]=4,[4]=4}\n',encoding='utf-8')
    (ASSETS / 'poses.lua').write_text('return {\n'+''.join(f' [{i}]={{idle=4,walk=4,attack=4,eat=4,sleep=2}},\n' for i in range(1,5))+'}\n',encoding='utf-8')
    # Montagem de prévia a partir dos mesmos PNGs consumidos pelo jogo.
    animation=[]
    for pose,count in [('repouso',4),('caminhar',4),('brincar',4),('comer',4),('dormir',2)]:
        for frame in range(1,count+1):
            panel=Image.new('RGB',(960,300),'white'); pen=ImageDraw.Draw(panel)
            pen.text((24,16),'SanrioKindle • '+pose.capitalize(),font=title,fill='black')
            for col,slug in enumerate(CHARACTERS):
                sprite=Image.open(ROOT/f'artes/sprites/{slug}/{pose}-{frame}.png').convert('RGBA').resize((192,192),Image.Resampling.NEAREST)
                panel.paste(sprite,(24+col*236,63),sprite)
                pen.text((32+col*236,266),NAMES[col],font=font,fill='black')
            animation.append(panel)
    animation[0].save(ROOT/'artes/previa-animada.gif',save_all=True,append_images=animation[1:],duration=450,loop=0,disposal=2)
    print('72 quadros e 16 aliases de repouso empacotados; originais preservados.')

if __name__ == '__main__': main()
