-- SanrioKindle game rules. Pure Lua 5.1; no device, network, or timer dependency.
local E = {}
local source=debug.getinfo(1,"S").source:sub(2):match("^(.*)/")
E.labels = dofile(source.."/labels.lua")
E.species = dofile(source.."/species.lua")
E.companion = dofile(source.."/companion.lua")
E.starters = {1,2,3,4}
E.evolution_branches = {}
E.evolution_stones = {}
-- Practice unlocks are SanrioKindle rules, not a battle-game learnset.
E.move_sets = {
 [1]={"Laços de amizade","Biscoitos caseiros","Dança do laço","Festa de leitura"},
 [2]={"Passeio nas nuvens","Saltos fofinhos","Dança das nuvens","Sonhos de leitura"},
 [3]={"Travessura gentil","Dança divertida","Surpresa de amigos","Festa do luar"},
 [4]={"Flores de carinho","Piquenique","Dança das flores","Histórias do jardim"},
}
E.badge_goals={
 {"First friend","Comece sua aventura"}, {"Kind heart","Cuide do seu parceiro 20 vezes"},
 {"Trail scout","Conclua 5 expedições"}, {"Field researcher","Conheça os 4 amigos"},
 {"Best buddies","Alcance 80 de vínculo"}, {"Veteran","Ganhe 300 XP"},
 {"Bookworm","Leia por 10 horas"}, {"A new arrival","Abra um presente"},
 {"All three trails","Conclua todas as trilhas"}, {"A place of our own","Coloque as quatro decorações"},
 {"Reading together","Guarde a lembrança de um livro"}, {"Finding a rhythm","Cumpra quatro metas semanais"},
 {"Favourite snack","Descubra uma fruta favorita"}, {"Sanrio friends","Conheça os 4 amigos da Sanrio"},
}
E.routes = {
 {name="Jardim dos Laços", seconds=1800, energy=12, berries=3, xp=12, pool={1,4}},
 {name="Caminho das Nuvens", seconds=7200, energy=20, berries=5, xp=22, pool={2,1}},
 {name="Trilha do Luar", seconds=14400, energy=28, berries=8, xp=35, pool={3,4}},
}
E.backgrounds={"Pradaria","Litoral","Caverna Lunar","Floresta","Campo Nevado","Cantinho de Leitura"}
E.egg_seconds=7200
E.egg_cost=3
E.weekly_targets={3600,7200,10800}
E.decorations={{name="Almofada",cost=5},{name="Planta",cost=8},{name="Luminária",cost=10},{name="Estante",cost=12}}
E.discoveries={{name="Arbusto de frutas",detail="Encontre 1 fruta"},{name="Pegadas",detail="Siga uma nova trilha por 3 XP"},{name="Acampamento",detail="Descanse por 8 de energia"}}
-- Cada passeio pode apresentar novos amigos; todas as rotas têm encontros.
E.routes[1].name="Jardim dos Laços";E.routes[1].pool={1,4}
E.routes[2].name="Caminho das Nuvens";E.routes[2].pool={2,1}
E.routes[3].name="Trilha do Luar";E.routes[3].pool={3,4}
function E.friendsCount(s)
 local n=0;for id=1,#E.species do if s.seen[tostring(id)] then n=n+1 end end;return n
end
local function clamp(n, lo, hi) return math.max(lo, math.min(hi,n)) end
local function integer(n,max) return type(n)=="number" and n==n and n>=0 and n<=max and n%1==0 end
function E.name(id) return E.species[id] and E.species[id][1] or "Presente" end
function E.displayName(s,id)
 id=id or s.species
 return s.nicknames and s.nicknames[tostring(id)] or E.name(id)
end
function E.validNickname(name)
 return E.companion.text.valid(name,12) and not name:find("=",1,true)
end
function E.reaction(s)
 local name=E.displayName(s)
 if s.resting then return name..(s.decor and s.decor[1] and " dorme na almofada." or " se aconchegou para uma soneca.") end
 if s.food<40 then return name.." fica de olho na cesta de frutas." end
 if s.energy<20 then return name.." solta um longo bocejo." end
 if s.dirt>70 then return name.." trouxe lama para o ninho." end
 if s.joy<40 then return name.." empurra uma bola até você." end
 if s.decor and s.decor[2] and tonumber(os.date("%H"))%3==0 then return name.." está cheirando a planta." end
 if s.decor and s.decor[4] and tonumber(os.date("%H"))%3==1 then return name.." está olhando a estante." end
 if s.bond>=80 then return name.." se acomoda ao seu lado." end
 if s.bond>=30 then return name.." se anima quando você volta." end
 return name.." fica feliz em ver você."
end
function E.level(s) return math.min(100,1+math.floor(s.xp/20)) end
function E.evolutionChoices(id)
 if E.evolution_branches[id] then return E.evolution_branches[id] end
 local p=E.species[id];return p and p[2] and {p[2]} or {}
end
local function parentOf(id)
 for parent in pairs(E.species) do
  for _,child in ipairs(E.evolutionChoices(parent)) do if child==id then return parent end end
 end
end
function E.evolutionLine(id)
 local line={id};local parent=parentOf(id)
 while parent do table.insert(line,1,parent);parent=parentOf(parent) end
 local choices=E.evolutionChoices(id)
 -- Branching partners show their choices separately; evolved partners retain their ancestry.
 while #choices==1 do id=choices[1];line[#line+1]=id;choices=E.evolutionChoices(id) end
 return line
end
function E.mood(s,now)
 if s.trip>0 then return E.tripLeft(s,now)==0 and "De volta da aventura" or "Explorando o mundo" end
 if s.resting then return "Tirando uma soneca" end
 if s.food<40 then return "Com um pouco de fome" end
 if s.energy<20 then return "Querendo uma soneca" end
 if s.dirt>70 then return "Precisando de uma limpeza" end
 if s.joy<40 then return "Querendo brincar" end
 if s.bond>=60 then return "Feliz em ver você" end
 return "Feliz por estar com você"
end
function E.moves(s)
 local root=E.evolutionLine(s.species)[1]
 local names=E.move_sets[s.species] or E.move_sets[1]
 local levels={1,7,20,36};local moves={}
 for i,name in ipairs(names) do moves[i]={name=name,level=levels[i]} end
 return moves
end
function E.canPlay(s,now)
 if s.species==0 then return false,"Escolha seu parceiro primeiro." end
 if s.trip>0 then return false,"Seu parceiro está explorando. Veja a trilha primeiro." end
 if s.resting then return false,"Seu parceiro está dormindo. Toque em Acordar primeiro." end
 if now-s.played<1800 then return false,"Brinque de novo em "..math.ceil((1800-now+s.played)/60).." min." end
 if s.energy<10 then return false,"Brincar exige 10 de energia. Descanse um pouco." end
 return true
end
function E.new(now)
 return {version=1, species=0, food=80, joy=80, energy=80, bond=0, xp=0,
  berries=6, last=now, gift=0, trained=0, played=0, cleaned=0, dirt=0,
  trip=0, due=0, trips=0, seen={}, badges={}, log={}, animation="eco",
  seed=now % 2147483646 + 1, resting=false, care=0, started=now}
end
function E.valid(s)
 if type(s)~="table" or (s.version~=1 and s.version~=2 and s.version~=3 and s.version~=4) then return false end
 for _,k in ipairs({"species","food","joy","energy","bond","xp","berries","last","gift","trained","played","cleaned","dirt","trip","due","trips","seed","care","started"}) do
  local n=s[k]; if type(n)~="number" or n~=n or n<0 or n>1e12 then return false end
 end
 if s.species~=0 and not E.species[s.species] then return false end
 if s.trip%1~=0 or s.trip>3 then return false end
 for _,k in ipairs({"food","joy","energy","bond","dirt"}) do if s[k]>100 then return false end end
 if s.berries>999 or s.seed<1 or s.seed>=2147483647 then return false end
 if type(s.seen)~="table" or type(s.badges)~="table" or type(s.log)~="table" then return false end
 for id,v in pairs(s.seen) do if not E.species[tonumber(id)] or v~=true then return false end end
 if #s.log>24 then return false end
 for _,v in ipairs(s.log) do if type(v)~="string" or #v>200 then return false end end
 if s.animation~="gentle" and s.animation~="eco" and s.animation~="off" then return false end
 if s.partners~=nil then
  if type(s.partners)~="table" then return false end
  for id,p in pairs(s.partners) do
   if type(id)~="string" or not E.species[tonumber(id)] or not s.seen[id] or type(p)~="table" then return false end
   for _,k in ipairs({"xp","bond"}) do local n=p[k];if type(n)~="number" or n~=n or n<0 or n>(k=="bond" and 100 or 1e12) then return false end end
  end
 end
 if s.reading~=nil then
  local r=s.reading
  if type(r)~="table" or type(r.enabled)~="boolean" or type(r.ko_ready)~="boolean" or type(r.kindle)~="table" then return false end
  for _,k in ipairs({"seconds","carry","kindle_at","ko"}) do
   local n=r[k];if type(n)~="number" or n~=n or n<0 or n>1e12 or n%1~=0 then return false end
  end
  local count=0
  for key,n in pairs(r.kindle) do
   count=count+1
   if count>10000 or type(key)~="string" or #key~=16 or not key:match("^%x+$")
    or type(n)~="number" or n~=n or n<0 or n>1e12 or n%1~=0 then return false end
  end
 end
 local function readingStart(n)
  return type(n)=="number" and n==n and n>=0 and n%1==0 and s.reading and n<=s.reading.seconds
 end
 if s.trail~=nil and (s.trip==0 or s.due~=0 or not readingStart(s.trail)) then return false end
 if s.egg~=nil then
  if type(s.egg)~="table" or not E.species[s.egg.id] or parentOf(s.egg.id) or not readingStart(s.egg.start) then return false end
 end
 if s.background~=nil and not E.backgrounds[s.background] then return false end
 if s.week~=nil then
  local w=s.week
  if type(w)~="table" or (w.target~=3600 and w.target~=7200 and w.target~=10800)
   or not integer(w.start,1e12) or not integer(w.seconds,1e12) or type(w.claimed)~="boolean" then return false end
 end
 if s.decor~=nil then
  if type(s.decor)~="table" then return false end
  for id,placed in pairs(s.decor) do if not E.decorations[id] or type(placed)~="boolean" then return false end end
 end
 if s.finds~=nil and (s.trip==0 or not integer(s.finds,3)) then return false end
 if s.nicknames~=nil then
  if type(s.nicknames)~="table" then return false end
  for id,name in pairs(s.nicknames) do
   if type(id)~="string" or not E.species[tonumber(id)] or not s.seen[id] or not E.validNickname(name) then return false end
  end
 end
 return type(s.resting)=="boolean" and E.companion.valid(s.companion,s,E)
end
function E.weekStart(now)
 local d=os.date("*t",now)
 return os.time{year=d.year,month=d.month,day=d.day-(d.wday+5)%7,hour=0,min=0,sec=0}
end
function E.updateWeek(s,now)
 if s.week then
  local start=E.weekStart(now)
  if start>s.week.start then s.week.start=start;s.week.seconds=0;s.week.claimed=false end
 end
end
function E.weekReward(s,now)
 local w=s.week
 if not w or w.claimed or w.seconds<w.target or s.species==0 then return end
 w.claimed=true
 local companion=E.companion.get(s);companion.goals=companion.goals+1
 local berries=math.min(5,999-s.berries);local xp=math.min(10,1e12-s.xp)
 s.berries=s.berries+berries;s.xp=s.xp+xp
 E.note(s,"Meta semanal cumprida! +"..berries.." frutas, +"..xp.." XP.",now)
end
function E.tripLeft(s,now)
 if s.trip==0 then return 0 end
 if s.trail~=nil then return math.max(0,E.routes[s.trip].seconds-(s.reading.seconds-s.trail)) end
 return clamp(s.due-now,0,E.routes[s.trip].seconds)
end
function E.eggLeft(s)
 if not s.egg then return E.egg_seconds end
 return math.max(0,E.egg_seconds-(s.reading.seconds-s.egg.start))
end
function E.discover(s,now)
 if s.trip==0 or s.finds==nil then return end
 local total=E.routes[s.trip].seconds
 local reached=math.min(3,math.floor(4*(total-E.tripLeft(s,now))/total))
 local events={}
 while s.finds<reached do
  s.finds=s.finds+1;local id=s.finds;local item=E.discoveries[id];local reward
  if id==1 then local n=math.min(1,999-s.berries);s.berries=s.berries+n;reward="+"..n.." fruta."
  elseif id==2 then local n=math.min(3,1e12-s.xp);s.xp=s.xp+n;reward="+"..n.." XP."
  else local n=math.min(8,100-s.energy);s.energy=s.energy+n;reward="+"..math.floor(n).." de energia." end
  E.note(s,item.name..": "..reward,now);events[#events+1]=item.name
 end
 if #events>0 then E.badges(s,now);return events end
end
function E.note(s,text,now)
 if now then text=os.date("%d/%m %H:%M",now).." | "..text end
 table.insert(s.log,1,text)
 while #s.log>24 do table.remove(s.log) end
 return text
end
function E.advance(s,now)
 E.updateWeek(s,now)
 -- Keep a high-water mark if the clock moves backwards. No duplicated rewards.
 if now<=s.last then E.discover(s,now);return end
 local hours=math.min((now-s.last)/3600,72)
 if s.species~=0 then
  s.food=clamp(s.food-hours*(s.resting and 1 or 2),15,100)
  s.joy=clamp(s.joy-hours*0.7,20,100)
  s.energy=clamp(s.energy+hours*(s.resting and 12 or 4),0,100)
  s.dirt=clamp(s.dirt+hours*1.3,0,100)
 end
 s.last=now
 E.discover(s,now)
end
local function rng(s,n)
 s.seed=(s.seed*48271)%2147483647
 return math.floor(s.seed% n)+1
end
function E.count(t) local n=0;for _,v in pairs(t) do if v then n=n+1 end end;return n end
function E.badges(s,now)
 E.companion.badges(s,E,now)
 local rules={ {"First friend",s.species~=0},{"Kind heart",s.care>=20},
  {"Trail scout",s.trips>=5},{"Field researcher",E.count(s.seen)>=#E.species},
  {"Best buddies",s.bond>=80},{"Veteran",s.xp>=300} }
 for _,r in ipairs(rules) do
  if r[2] and not s.badges[r[1]] then s.badges[r[1]]=true;E.note(s,"Insígnia conquistada: "..E.labels.get(r[1]).."!",now) end
 end
end
function E.ready(s)
 local p=E.species[s.species]
 return p and p[2] and s.xp>=p[3] and s.bond>=30
end
function E.readingReward(s,seconds,now)
 local r=s.reading;if not r or not r.enabled then return nil end
 if type(seconds)~="number" or seconds~=seconds or seconds<0 or seconds>1e12 then return nil end
 seconds=math.floor(seconds)
 E.updateWeek(s,now)
 local old_berries,old_xp=s.berries,s.xp
 local trip_before=s.trip>0 and E.routes[s.trip].seconds-E.tripLeft(s,s.trail~=nil and now or s.last) or 0
 local egg_before=s.egg and E.egg_seconds-E.eggLeft(s) or 0
 r.seconds=math.min(1e12,r.seconds+seconds);r.carry=math.min(1e12,r.carry+seconds)
 if s.species==0 then return nil end
 local rewards=math.floor(r.carry/900)
 r.carry=r.carry%900
 local berries=math.min(rewards,999-s.berries)
 s.berries=s.berries+berries;s.xp=math.min(1e12,s.xp+rewards*3)
 local claimed=s.week and s.week.claimed
 if s.week then s.week.seconds=math.min(1e12,s.week.seconds+seconds);E.weekReward(s,now) end
 local events=E.discover(s,now)
 local earned_berries,earned_xp=s.berries-old_berries,s.xp-old_xp
 local recap=seconds>0 and {seconds=seconds,berries=earned_berries,xp=earned_xp,events=events,weekly=s.week and s.week.claimed and not claimed,
  route=s.trip,trip_before=trip_before,trip_after=s.trip>0 and E.routes[s.trip].seconds-E.tripLeft(s,now) or 0,
  egg=s.egg~=nil,egg_before=egg_before,egg_after=s.egg and E.egg_seconds-E.eggLeft(s) or 0} or nil
 E.badges(s,now)
 if earned_berries==0 and earned_xp==0 then return nil,recap end
 local message="Leitura: +"..earned_berries..(earned_berries==1 and " fruta" or " frutas")..", +"..earned_xp.." XP."
 E.note(s,message,now);E.badges(s,now);return message,recap
end
function E.act(s,action,arg,now)
 E.advance(s,now)
 local extra=E.companion.act(s,E,action,arg,now)
 if extra then return extra end
 local function done(msg,anim)
  E.note(s,msg,now); E.badges(s,now); return msg,anim
 end
 if action=="choose" and s.species==0 then
  if not E.species[arg] then return "Escolha um amigo da lista." end
  s.species=arg;s.seen[tostring(arg)]=true;s.gift=now;s.started=now
  E.companion.mark(s,arg,now)
  E.readingReward(s,0,now)
  return done(E.name(arg).." é seu novo amigo!","hello")
 end
 if action=="animation" then
  if arg=="gentle" or arg=="eco" or arg=="off" then s.animation=arg end
  return "Animação: "..s.animation
 end
 if action=="background" then
  if E.backgrounds[arg] then s.background=arg;s.version=math.max(s.version,3) end
  return "Cenário: "..E.backgrounds[s.background or 1]
 end
 if s.species==0 then return "Escolha seu primeiro parceiro." end
 if action=="nickname" then
  if type(arg)~="string" then return "Escolha um apelido com até 12 caracteres." end
  local name=arg:gsub("^%s+",""):gsub("%s+$","")
  if name~="" and not E.validNickname(name) then return "Use até 12 caracteres, sem quebras de linha." end
  s.nicknames=s.nicknames or {};s.nicknames[tostring(s.species)]=name~="" and name or nil;s.version=math.max(s.version,3)
  return done(name~="" and "Você chamou seu parceiro de "..name.."." or "De volta a "..E.name(s.species)..".")
 elseif action=="decorate" then
  local item=E.decorations[arg];if not item then return "Escolha algo para seu cantinho." end
  s.decor=s.decor or {}
  if s.decor[arg]==nil then
   if s.berries<item.cost then return "Você precisa de "..item.cost.." frutas para comprar: "..item.name:lower().."." end
   s.berries=s.berries-item.cost;s.decor[arg]=true;s.version=math.max(s.version,3)
   return done("Você comprou: "..item.name:lower().." para seu cantinho.")
  end
  s.decor[arg]=not s.decor[arg]
  return s.decor[arg] and item.name.." colocado no cantinho." or item.name.." guardado."
 elseif action=="goal" then
  if arg~=3600 and arg~=7200 and arg~=10800 then return "Escolha 60, 120 ou 180 minutos." end
  s.week=s.week or {start=E.weekStart(now),seconds=0,claimed=false};s.week.target=arg;s.version=math.max(s.version,3)
  E.weekReward(s,now)
  return done("Meta semanal: "..arg/60 .." minutos. Leia quando tiver vontade.")
 elseif action=="check" then
  if s.egg and E.eggLeft(s)==0 then return "Seu presente está pronto! Toque nele para conhecer seu novo amigo." end
  if s.trip>0 and E.tripLeft(s,now)==0 then return "Seu parceiro voltou! Toque em Explorar para recolher." end
  if s.trip>0 then return E.displayName(s).." está explorando: "..E.routes[s.trip].name.."." end
  return E.reaction(s)
 elseif action=="gift" then
  if now-s.gift<86400 then return "A cesta de frutas é reabastecida a cada 24 horas." end
  s.gift=now;s.berries=math.min(999,s.berries+5)
  return done("A cesta tem 5 frutas fresquinhas!","feed")
 elseif action=="egg" then
  if s.egg then return "Você já tem um presente para abrir." end
  if not s.reading or not s.reading.enabled then return "Ative as recompensas de leitura para preparar um presente." end
  if s.berries<E.egg_cost then return "Um presente custa "..E.egg_cost.." frutas." end
  local pool,all={},{}
  for id=1,#E.species do
   if not parentOf(id) then
    all[#all+1]=id;if not s.seen[tostring(id)] then pool[#pool+1]=id end
   end
  end
  if #pool==0 then pool=all end
  s.egg={id=pool[rng(s,#pool)],start=s.reading.seconds};s.version=math.max(s.version,3);s.berries=s.berries-E.egg_cost
  return done("Um presente para seus próximos capítulos. Leia por 120 minutos para abri-lo.")
 elseif action=="hatch" then
  if not s.egg then return "Pegue um presente primeiro." end
  if E.eggLeft(s)>0 then return "Seu presente precisa de mais "..math.ceil(E.eggLeft(s)/60).." minutos de leitura." end
  local id=s.egg.id;s.seen[tostring(id)]=true;s.egg=nil
  E.companion.mark(s,id,now);local c=E.companion.get(s);c.hatches=c.hatches+1
  return done(E.name(id).." chegou de surpresa! Encontre seu novo amigo no diário.")
 elseif action=="collect" then
  if s.trip==0 then return "Escolha uma trilha para explorar." end
  local left=E.tripLeft(s,now)
  if left>0 then return s.trail~=nil and "Leia por mais "..math.ceil(left/60).." minutos para concluir a trilha."
   or "Ainda explorando. Volte em "..math.ceil(left/60).." min." end
  local r=E.routes[s.trip];local pool={}
  for _,id in ipairs(r.pool) do if not s.seen[tostring(id)] then pool[#pool+1]=id end end
  if #pool==0 then pool=r.pool end
  local id=pool[rng(s,#pool)]
  local fresh=not s.seen[tostring(id)];s.seen[tostring(id)]=true
  s.berries=math.min(999,s.berries+r.berries);s.xp=s.xp+r.xp;s.bond=clamp(s.bond+4,0,100)
  E.companion.mark(s,id,now);local story=E.companion.finishTrip(s,E)
  s.trips=s.trips+1;s.trip=0;s.due=0;s.trail=nil;s.finds=nil
  return done((fresh and "Novo: " or "Encontrou: ")..E.name(id).."! +"..r.berries.." frutas, +"..r.xp.." XP."..(story or ""),"explore")
 end
 if s.trip>0 then return "Seu parceiro está explorando. Toque em Explorar para saber mais." end
 if action=="rest" then
  s.resting=not s.resting
  return done(s.resting and "Hora da soneca! O descanso continua enquanto você lê." or "Acordado e pronto para uma aventura.","rest")
 end
 if s.resting then return "Seu parceiro está dormindo. Toque em Acordar primeiro." end
 if action=="partner" then
  if not E.species[arg] then return "Escolha um amigo da lista." end
  if arg==s.species then return E.name(arg).." já está com você." end
  s.partners=s.partners or {};s.partners[tostring(s.species)]={xp=s.xp,bond=s.bond}
  local p=s.partners[tostring(arg)] or {xp=0,bond=0}
  s.species=arg;s.xp=p.xp;s.bond=p.bond;s.seen[tostring(arg)]=true
  E.companion.mark(s,arg,now)
  return done(E.name(arg).." se juntou a você. Seus outros amigos mantêm o progresso.","hello")
 elseif action=="feed" then
  if s.berries<1 then return "Sem frutas. Explore ou confira a cesta." end
  if s.food>=95 then return "Barriguinha cheia! Guarde essa fruta para depois." end
  s.berries=s.berries-1;s.food=clamp(s.food+24,0,100);s.bond=clamp(s.bond+2,0,100);s.care=s.care+1
  local _,favourite=E.companion.profile(s,s.species,E)
  if arg==favourite then
   E.companion.get(s).tastes[tostring(s.species)]=true;s.bond=clamp(s.bond+1,0,100)
   return done(E.displayName(s).." se animou. "..favourite.." é uma das favoritas!","feed")
  end
  return done("Fruta comida.","feed")
 elseif action=="play" then
  local allowed,why=E.canPlay(s,now);if not allowed then return why end
  local perfect=arg=="perfect"
  s.played=now;s.energy=s.energy-10;s.joy=clamp(s.joy+20,0,100);s.bond=clamp(s.bond+4,0,100);s.xp=s.xp+5;s.care=s.care+1
  if perfect then s.xp=s.xp+3 end
  return done(perfect and "Trilha perfeita! +8 XP, +4 de vínculo." or "Boa tentativa! +5 XP, +4 de vínculo.","play")
 elseif action=="train" then
  if now-s.trained<3600 then return "Treino disponível em "..math.ceil((3600-now+s.trained)/60).." min." end
  if s.energy<18 or s.food<30 then return "Praticar exige 18 de energia e 30 de saciedade." end
  local move=arg or E.moves(s)[1].name;local unlocked=false
  for _,m in ipairs(E.moves(s)) do if m.name==move and E.level(s)>=m.level then unlocked=true end end
  if not unlocked then return "Esse golpe ainda não está disponível. Continuem crescendo juntos." end
  s.trained=now;s.energy=s.energy-18;s.food=s.food-8;s.xp=s.xp+12;s.bond=clamp(s.bond+2,0,100)
  return done(move.." em treino! +12 XP, +2 de vínculo.","train")
 elseif action=="clean" then
  if s.dirt<15 then return "Já está tudo limpinho." end
  s.dirt=0;s.joy=clamp(s.joy+8,0,100);s.bond=clamp(s.bond+2,0,100);s.care=s.care+1;s.cleaned=now
  return done("Ninho limpo.","clean")
 elseif action=="trip" or action=="readingtrip" then
  local r=E.routes[arg];if not r then return "Escolha uma trilha." end
  if action=="readingtrip" and (not s.reading or not s.reading.enabled) then return "Ative as recompensas de leitura para iniciar uma trilha de leitura." end
  if s.energy<r.energy then return "Esta trilha exige "..r.energy.." de energia." end
  if s.food<30 then return "Alimente seu parceiro antes de partir." end
  s.energy=s.energy-r.energy;s.trip=arg;s.due=now+r.seconds;s.finds=0;s.version=math.max(s.version,3)
  E.companion.get(s).journey={event=rng(s,#E.companion.events)}
  if action=="readingtrip" then
   s.trail=s.reading.seconds;s.due=0;s.version=math.max(s.version,3)
   return done("Partiu: "..r.name.."! Leia por "..r.seconds/60 .." minutos para concluir.","explore")
  end
  return done("Partiu: "..r.name.."! Volte em "..r.seconds/60 .." min.","explore")

 end
 return "Tudo pronto quando você quiser."
end
return E
