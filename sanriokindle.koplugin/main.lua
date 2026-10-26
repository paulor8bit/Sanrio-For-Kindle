local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local DataStorage = require("datastorage")
local ffiUtil = require("ffi/util")
local InfoMessage = require("ui/widget/infomessage")
local SanrioKindle = WidgetContainer:extend{name="sanriokindle",is_doc_only=false}

function SanrioKindle:init()
 -- KOReader supplies self.view for the book. The game uses self.pet_view.
 self.engine=dofile(self.path.."/engine.lua")
 self.storage=dofile(self.path.."/storage.lua")
 self.fs=dofile(self.path.."/filesystem.lua")
 self.reading=dofile(self.path.."/reading.lua")
 self.timer=dofile(self.path.."/reading_timer.lua")
 self.clock=self.timer.new()
 self.savepath,self.path_error=self.storage.location(DataStorage:getSettingsDir().."/sanriokindle.dat",self.fs)
 if self.savepath then self.counterpath=self.savepath..".reading";self.reading.loadCache(self.savepath..".scan-cache") end
 if self.savepath then
  self.backups=dofile(self.path.."/backups.lua").new(self.savepath,self.engine,self.reading,self.fs,ffiUtil.fsyncOpenedFile,ffiUtil.fsyncDirectory)
 end
 self.View=dofile(self.path.."/view.lua")
 self.ui.menu:registerToMainMenu(self)
 self:installSleepScreen()
end
function SanrioKindle:addToMainMenu(items)
 items.sanriokindle={text="SanrioKindle - Amigos de leitura",sorting_hint="more_tools",callback=function() self:openPet() end}
end
function SanrioKindle:openPet()
 if self.pet_view then return end
 if not self.savepath then UIManager:show(InfoMessage:new{text=self.path_error});return end
 self:pauseReading()
 local notice
 self.session,notice=self.storage.open(self.savepath,{DataStorage:getSettingsDir().."/sanriokindle.dat",
  "/mnt/us/extensions/sanriokindle/data/sanriokindle.dat"},self.engine,self.fs,function() return self.backups:recover() end)
 if not self.session then
  UIManager:show(InfoMessage:new{text="SanrioKindle: "..notice});self:resumeReading()
  return
 end
 self.state=self.session.state or self.engine.new(os.time());notice=self.session.notice
 self:flushReading()
 self.recap=nil
 local visit=self.reading.visit(self.state)
 self.reading.init(self.state)
 self.engine.companion.resume(self.state,self.engine,os.time())
 self.engine.advance(self.state,os.time())
 if not self:save() then
  UIManager:show(InfoMessage:new{text="O SanrioKindle não conseguiu salvar. Verifique o espaço livre no Kindle."})
  self:onPetClosed();return
 end
 self.pet_view=self.View:new{owner=self,engine=self.engine,state=self.state,path=self.path}
 if notice then self.pet_view.message=notice end
 UIManager:show(self.pet_view,"full")
 self:startReadingScan(visit)
 if self.pet_view.screen=="home" and self.state.species~=0 and self.engine.tripLeft(self.state,os.time())==0 then
  self.pet_view:animate(self.state.resting and "ambient_sleep" or "ambient")
 end
end
function SanrioKindle:flushReading()
 if not self.counterpath then return end
 if self.fs.mode(self.savepath..".restore") then self.reading_error="Reabra o SanrioKindle para concluir a restauração.";return end
 local pending=self.clock.pending
 local unlock,err=self.fs.lock(self.counterpath..".session")
 if not unlock then self.reading_error=err;return end
 local total,primary,days;total,err,primary,days=self.reading.counter(self.counterpath)
 if total then
  days=days or {};for day,n in pairs(self.clock.days or {}) do days[day]=(days[day] or 0)+n end
  local keys={};for day in pairs(days) do keys[#keys+1]=day end;table.sort(keys);while #keys>62 do days[table.remove(keys,1)]=nil end
  local saved,committed=primary and pending==0 and not self.reading_unsynced,false
  if not saved then
   saved,err,committed=self.reading.saveCounter(self.counterpath,total+pending,ffiUtil.fsyncOpenedFile,ffiUtil.fsyncDirectory,days)
   -- A renamed counter still needs a retry if its directory could not be synced.
   if saved then self.reading_unsynced=nil elseif committed then self.reading_unsynced=true end
  end
  if saved or committed then self.clock.pending=self.clock.pending-pending;self.clock.days={};self.clock.total=total+pending end
 end
 unlock();self.reading_error=err
end
function SanrioKindle:pauseReading()
 self.timer.pause(self.clock,os.time());self:flushReading()
end
function SanrioKindle:resumeReading()
 if self.document_open and not self.suspended and not self.reading_paused and not self.pet_view then
  self.timer.resume(self.clock,self.clock.page,os.time())
 end
end
function SanrioKindle:onReaderReady()
 self.document_open=true
 if not self.session and self.savepath then self.state=self.storage.load(self.savepath,self.engine) end
 self:updateCompanion();self:resumeReading()
end
function SanrioKindle:onPageUpdate(page)
 if not self.document_open then self.clock.page=page;return end
 if self.pet_view or self.suspended or self.reading_paused then self.clock.page=page;return end
 self.timer.page(self.clock,page,os.time())
 if self.clock.pending>=60 then self:flushReading() end
end
function SanrioKindle:onReadingPaused()
 self.reading_paused=true;self:pauseReading()
end
function SanrioKindle:onReadingResumed()
 self.reading_paused=false;self:resumeReading()
end
function SanrioKindle:onCloseDocument()
 self.document_open=false;self:pauseReading()
 if self.footer_owner then self.footer_owner:removeAdditionalFooterContent(self.footer_content);self.footer_owner=nil end
end
function SanrioKindle:onFlushSettings() self:flushReading() end
function SanrioKindle:finishReadingScan(counters,status,visit)
 if counters then self.reading.saveCache() end
 local ko,err,primary,days=self.reading.counter(self.counterpath)
 self.reading_status={status,(err or self.reading_error) and "KOReader: não foi possível salvar o tempo de leitura" or "KOReader: registro automático ativo"}
 local message,recap=self.reading.collect(self.state,self.engine,counters,ko,os.time(),days,visit)
 if recap then self.recap=recap end
 return message
end
function SanrioKindle:cancelReadingScan()
 if self.scan_step then UIManager:unschedule(self.scan_step) end
 self.scan_step=nil;self.reading_busy=false
end
function SanrioKindle:startReadingScan(visit)
 visit=visit or self.reading.visit(self.state)
 self:cancelReadingScan();self.reading_busy=true
 local step=self.reading.scanAsync("/mnt/us/documents",self.fs)
 self.scan_step=function()
  if not self.pet_view or self.suspended then self:cancelReadingScan();return end
  local done,counters,status=step()
  if done then
   self:cancelReadingScan();self:finishReadingScan(counters,status,visit);self:save()
   self.pet_view:freeImages();UIManager:setDirty(self.pet_view,"ui")
  else UIManager:scheduleIn(0.01,self.scan_step) end
 end
 UIManager:scheduleIn(0.05,self.scan_step)
end
function SanrioKindle:syncReading()
 self:cancelReadingScan()
 return self:finishReadingScan(self.reading.scan("/mnt/us/documents",self.fs))
end
function SanrioKindle:rescanReading() self.reading.clearCache();self:startReadingScan() end
function SanrioKindle:toggleReading()
 self:syncReading();self.state.reading.enabled=not self.state.reading.enabled
 return self:save()
end
function SanrioKindle:onPetClosed()
 self:cancelReadingScan();self:updateCompanion()
 if self.session then self.session.close();self.session=nil end
 self:resumeReading()
end
function SanrioKindle:save()
 if self.backups and self.backups.blocked then return nil,"Reabra o SanrioKindle para concluir a restauração." end
 if self.savepath and self.state then
  local ok,err=self.storage.save(self.savepath,self.state,self.engine,ffiUtil.fsyncOpenedFile,ffiUtil.fsyncDirectory)
  self.save_error=not ok
  if not ok then return nil,err end
 end
 return true
end
function SanrioKindle:onSuspend()
 self.suspended=true;self:pauseReading();self:cancelReadingScan()
 self:companionState(function(s) self.engine.companion.suspend(s,self.engine,os.time()) end)
 if self.pet_view then self.pet_view:onSuspend() end
end
function SanrioKindle:onResume()
 local visit=self.state and self.reading.visit(self.state)
 self:companionState(function(s) self.engine.companion.resume(s,self.engine,os.time()) end)
 self.suspended=false;self:updateCompanion();self:resumeReading()
 if self.pet_view then self.pet_view:onResume();self:startReadingScan(visit) end
end
function SanrioKindle:onClose()
 self:detachCompanion();self:cancelReadingScan()
 self.document_open=false;self:pauseReading()
 if self.pet_view then self.pet_view:leave() end
 self:onPetClosed()
end
function SanrioKindle:onCloseWidget()
 -- Closing a book or the file browser sends CloseWidget, not Close.
 self:onClose()
end
dofile(debug.getinfo(1,"S").source:sub(2):match("^(.*)/").."/reader_companion.lua").attach(SanrioKindle,UIManager)
return SanrioKindle
