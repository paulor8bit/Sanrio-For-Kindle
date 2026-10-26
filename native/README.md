# SanrioKindle PT-BR — versão independente

A edição KUAL carrega o mesmo jogo Lua e a mesma interface do plugin KOReader por um host local de desenho e toque. Não precisa de KOReader.

O executável reúne Lua, FBInk e musl, compilado estaticamente para Kindle ARMv7/Linux com tela sensível ao toque. O funcionamento depende das interfaces de tela, toque e eventos de energia do aparelho. Use a orientação retrato.

## Compilar

Instale Python, Git e Zig 0.13.0. Na raiz do projeto:

```sh
python tools/build_native.py --zig /caminho/para/zig --deps /caminho/para/cache
python tools/package_release.py --deps /caminho/para/cache
```

No Windows, use o caminho de `zig.exe`. O build baixa revisões fixas de Lua, FBInk e stb. Os arquivos gerados ficam em `native/build/`. O empacotador inclui as fontes exatas das dependências no ZIP `fontes.zip`. Mantenha esse ZIP junto ao executável ao redistribuir.

Acrescente `--headless` ao primeiro comando para compilar um executável de teste para Windows ou Linux. Depois, dentro de `native/build/extension`, execute:

```sh
./sanriokindle-headless ../../../tests/test_native.lua native-test.pgm
```

No Windows, use `./sanriokindle-headless.exe`. O teste confere desenho de texto e imagens, integração Lua, ações, troca de parceiros, reabertura de saves e suspensão. Ele não testa o toque Linux nem a atualização física da tela de tinta eletrônica.

## Verificar no Kindle

Faça backup do save. Confira seleção de parceiro e alinhamento do toque, alimente uma vez, saia e abra novamente. Inicie uma animação, pressione o botão de energia, acorde o aparelho e reabra pelo KUAL. Confira também capa magnética, descanso automático e aberturas repetidas. A tela inicial e a barra do Kindle devem voltar a funcionar após sair.

Ao receber `goingToScreenSaver`, o jogo salva e sai. O inicializador pausa temporariamente `awesome` e desativa a barra Pillow, restaurando ambos ao sair. Se o observador de energia falhar, o jogo fecha. Não altera arquivos de firmware nem impede o descanso.

O toque contempla toque simples e multitoque no slot zero, escalando as coordenadas conforme os eixos informados pelo FBInk. Calibração e rotação exigem validação física.

As duas edições usam `/mnt/us/sanriokindle/sanriokindle.dat`. Na primeira abertura, o save legado mais recente é copiado de `extensions/sanriokindle/data` ou da pasta de configurações do KOReader. Os originais são preservados. Fora do Kindle, a localização local anterior continua sendo usada. Os pacotes não contêm saves de teste.

O jogo consulta os registros locais de leitura em pequenos lotes após abrir. KOReader exporta o tempo de virada de páginas para a pasta compartilhada, e ambas as edições podem recolher as recompensas.

O descanso automático opcional mantém um observador de energia depois de fechar o jogo. Ele chama `--suspend` e `--resume` sem abrir o framebuffer nem capturar o toque. KUAL usa a tela normal de descanso do Kindle.

## Licenças

Host nativo e inicializador: GPL-3.0-or-later. Jogo compartilhado: MIT. Os avisos de FBInk, Lua, stb, DejaVu e Bitstream Vera foram preservados. Os personagens pertencem à Sanrio; veja `game/CREDITS.txt`.
