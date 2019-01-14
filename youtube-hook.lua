local utils = require 'mp.utils'
local msg = require 'mp.msg'

local function unurl(x)
	return (x:gsub("%%(..)",function(x)return string.char(tonumber(x,16))end))
end
local function unjs(x)
	return (x:gsub("\\u(....)",function(x)return string.char(tonumber(x,16))end))
end

local function backtick(x)
	local f=io.popen(x, "r")
	if f then
		local s=f:read"*all"
		f:close()
		return s
	end
end
local function wflush(x)
	msg.warn(x)
end

local function print (s)
  wflush(s)
end

local function print_r (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      print(formatting)
      print_r(v, indent+1)
    elseif type(v) == 'boolean' then
      print(formatting .. tostring(v))      
    else
      print(formatting .. v)
    end
  end
end




local function open_youtube(youtube_url) 

  wflush(youtube_url)

  local id=youtube_url:match"[?&]v=([^&]*)"
  wflush(id)
  assert(not id:match"[^a-zA-Z0-9_-]","Does not look like a valid ID:\n"..id)



  local page=assert(backtick("/usr/bin/curl https://www.youtube.com/watch?v="..id), "Could not fetch http://youtube.com/watch?v="..id)

  --print"Done"

  local formats=unjs(assert(page:match'"adaptive_fmts":"([^"]*)',"Could not find format specifiers"))

  
  
  
  local formattbl={}
  for p in formats:gmatch"[^&,]+" do
    local k,v=p:match"^([^=]*)=(.*)$"
    if not k then
      print("Odd format specifier: "..p)
    end
    table.insert(formattbl,{unurl(k),unurl(v)})
  end
  
  --print_r(formattbl);
  
  local audios={}
  local videos={}
  local i=#formattbl
  local sep=formattbl[i][1]
  while i>0 do
    assert(formattbl[i][1]==sep,"Expected "..sep..", got: "..formattbl[i][1])
    local fmt={}
    local k,v=formattbl[i][1],formattbl[i][2]
    fmt[k]=v
    i=i-1
    while i>0 do
      local k,v=formattbl[i][1],formattbl[i][2]
      if k==sep then
        break
      end
      fmt[k]=v
      i=i-1
    end
    if fmt.url then
      if fmt.type then
        local kind,codec=fmt.type:match"^([^/]*)/(.*)$"
        fmt.codec=(codec or""):gsub('+codecs="([^"]*)"',"%1")
        if kind=="audio" then
          table.insert(audios,fmt)
        elseif kind=="video" then
          table.insert(videos,fmt)
        else
          wflush("Neither video nor audio, ignoring:\n"..fmt.type)
        end
      else
        wflush"Format without a type, ignoring"
      end
    else
      wflush"Format without an url, ignoring"
    end
  end

  --print_r(videos);
  --print_r(audios);
  
  local af,aurl
  local vurl
  if #audios>0 then
    local n=1
    
    
    

      local maxb = 0
      local choice = 0
      for i,v in ipairs(audios) do
        --print(tonumber(v.bitrate))
        
        if (tonumber(v.bitrate) < maxb or maxb == 0) then
          --print_r(v);
          maxb=tonumber(v.bitrate)
          choice=i
        end
      end
      
      n=choice
      --print(n)

    if audios[n] then
      aurl=audios[n].url    
    end
  else
    wflush("No audio formats available")
  end

  if #videos>0 then
    
    for i,v in pairs(videos) do
      if v.size == "1280x720" then
        if(v.codec == "webm;vp9") then
          choice = i
        end
      end
    end
    
    if not choice then
      for i,v in pairs(videos) do
        if v.size == "1280x720" then      
            choice = i
        end
      end
    end
    
    if not choice then
      for i,v in pairs(videos) do
        if v.quality_label and v.quality_label == "720p" then      
            choice = i
        end
      end
    end
    
    if not choice then
      choice = 1
    end
    
    if choice then
      vurl=videos[choice].url
    end

    
    

    
  else
    wflush"No video formats available"
  end

  wflush(aurl)
  wflush(vurl)

  if aurl then
    if vurl then
      
      mp.set_property("stream-open-filename", vurl)
      mp.commandv("audio-add", aurl)
    end
  end 

end

mp.add_hook("on_load", 20, function ()
    local youtube_url = mp.get_property("stream-open-filename")
    
    wflush("starting");
    if (youtube_url:match("youtube"))  then
      wflush(youtube_url);
      open_youtube(youtube_url)        
    end
end)