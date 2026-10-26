-- Translate display labels only. Save keys and type filters stay stable.
local labels = {
 ["Grass"]="Planta", ["Fire"]="Fogo", ["Water"]="Água", ["Electric"]="Elétrico",
 ["Normal"]="Normal", ["Bug"]="Inseto", ["Flying"]="Voador", ["Poison"]="Veneno",
 ["Ground"]="Terra", ["Rock"]="Pedra", ["Psychic"]="Psíquico", ["Ice"]="Gelo",
 ["Fighting"]="Lutador", ["Ghost"]="Fantasma", ["Dragon"]="Dragão", ["Fairy"]="Fada", ["Steel"]="Aço",
 ["First friend"]="Primeiro amigo", ["Kind heart"]="Bom coração", ["Trail scout"]="Desbravador",
 ["Field researcher"]="Amigo da turma", ["Best buddies"]="Melhores amigos", ["Veteran"]="Veterano",
 ["Bookworm"]="Devorador de livros", ["A new arrival"]="Um novo amigo", ["All three trails"]="As três trilhas",
 ["A place of our own"]="Nosso cantinho", ["Reading together"]="Lendo juntos",
 ["Finding a rhythm"]="No ritmo da leitura", ["Favourite snack"]="Lanche favorito", ["Sanrio friends"]="Turma reunida",
 ["gentle"]="suave", ["eco"]="econômica", ["off"]="desligada",
 ["berries"]="frutas", ["bond"]="de vínculo", ["energy"]="de energia", ["xp"]="XP",
}
local M={}
function M.get(value) return labels[value] or value end
function M.types(value) return (value:gsub("%a+",M.get)) end
return M
