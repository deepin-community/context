if not modules then modules = { } end modules ['s-fonts-features'] = {
    version   = 1.001,
    comment   = "companion to s-fonts-features.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.fonts          = moduledata.fonts          or { }
moduledata.fonts.features = moduledata.fonts.features or { }

-- for the moment only otf

local rawget = rawget
local insert, remove, sortedhash = table.insert, table.remove, table.sortedhash

local v_yes  = interfaces.variables.yes
local v_no   = interfaces.variables.no
local c_name = interfaces.constants.name

local context = context
local NC, NR, bold = context.NC, context.NR, context.bold

function moduledata.fonts.features.showused(specification)

    specification = interfaces.checkedspecification(specification)

 -- local list = utilities.parsers.settings_to_set(specification.list or "all")

    context.starttabulate { "|T|T|T|T|T|" }

        context.HL()

            NC() bold("feature")
            NC()
            NC() bold("description")
            NC() bold("value")
            NC() bold("internal")
            NC() NR()

        context.HL()

            local usedfeatures = fonts.handlers.otf.statistics.usedfeatures
            local features     = fonts.handlers.otf.tables.features
            local descriptions = fonts.handlers.otf.features.descriptions

            for feature, keys in sortedhash(usedfeatures) do
             -- if list.all or (list.otf and rawget(features,feature)) or (list.extra and rawget(descriptions,feature)) then
                    local done = false
                    for k, v in sortedhash(keys) do
                        if done then
                            NC()
                            NC()
                            NC()
                        elseif rawget(descriptions,feature) then
                            NC() context(feature)
                            NC() context("+") -- extra
                            NC() context.escaped(descriptions[feature])
                            done = true
                        elseif rawget(features,feature) then
                            NC() context(feature)
                            NC()              -- otf
                            NC() context.escaped(features[feature])
                            done = true
                        else
                            NC() context(feature)
                            NC() context("-") -- unknown
                            NC()
                            done = true
                        end
                        NC() context(k)
                        NC() context(tostring(v))
                        NC() NR()
                    end
             -- end
            end

        context.HL()

    context.stoptabulate()

end

local function collectkerns(tfmdata,feature)
    local combinations = { }
    local resources    = tfmdata.resources
    local characters   = tfmdata.characters
    local sequences    = resources.sequences
    local lookuphash   = resources.lookuphash
    local feature      = feature or "kern"
    if sequences then
        for i=1,#sequences do
            local sequence = sequences[i]
            if sequence.features and sequence.features[feature] then
                local steps = sequence.steps
                for i=1,#steps do
                    local step   = steps[i]
                    local format = step.format
                    for unicode, hash in table.sortedhash(step.coverage) do
                        local kerns = combinations[unicode]
                        if not kerns then
                            kerns = { }
                            combinations[unicode] = kerns
                        end
                        for otherunicode, kern in table.sortedhash(hash) do
                            if format == "pair" then
                                local f = kern[1]
                                local s = kern[2]
                                if f then
                                    if s then
                                        -- todo
                                    else
                                        if not kerns[otherunicode] and f[3] ~= 0 then
                                            kerns[otherunicode] = f[3]
                                        end
                                    end
                                elseif s then
                                    -- todo
                                end
                            elseif format == "kern" then
                                if not kerns[otherunicode] and kern ~= 0 then
                                    kerns[otherunicode] = kern
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return combinations
end

local showkernpair = context.showkernpair

function moduledata.fonts.features.showbasekerns(specification)
    -- assumes that the font is loaded in base mode
    specification = interfaces.checkedspecification(specification)
    local id, cs  = fonts.definers.internal(specification,"<module:fonts:features:font>")
    local tfmdata = fonts.hashes.identifiers[id]
    local done    = false
    for unicode, character in sortedhash(tfmdata.characters) do
        local kerns = character.kerns
        if kerns then
            context.par()
            for othercode, kern in sortedhash(kerns) do
                showkernpair(unicode,kern,othercode)
            end
            context.par()
            done = true
        end
    end
    if not done then
        context("no kern pairs found")
        context.par()
    end
end

function moduledata.fonts.features.showallkerns(specification)
    specification    = interfaces.checkedspecification(specification)
    local id, cs     = fonts.definers.internal(specification,"<module:fonts:features:font>")
    local tfmdata    = fonts.hashes.identifiers[id]
    local allkerns   = collectkerns(tfmdata)
    local characters = tfmdata.characters
    local hfactor    = tfmdata.parameters.hfactor
    if next(allkerns) then
        for first, pairs in sortedhash(allkerns) do
            context.par()
            for second, kern in sortedhash(pairs) do
             -- local kerns = characters[first].kerns
             -- if not kerns and pairs[second] then
             --     -- weird
             -- end
                showkernpair(first,kern*hfactor,second)
            end
            context.par()
        end
    else
        context("no kern pairs found")
        context.par()
    end
end

function moduledata.fonts.features.showfeatureset(specification)
    specification = interfaces.checkedspecification(specification)
    local name = specification[c_name]
    if name then
        local s = fonts.specifiers.contextsetups[name]
        if s then
            local t = table.copy(s)
            t.number = nil
            if t and next(t) then
                context.starttabulate { "|T|T|" }
                    for k, v in sortedhash(t) do
                       NC() context(k) NC() context(v == true and v_yes or v == false and v_no or tostring(v)) NC() NR()
                    end
                context.stoptabulate()
            end
        end
    end
end

-- The next one looks a bit like the collector in font-oup.lua.

local function collectligatures(tfmdata)
    local sequences = tfmdata.resources.sequences

    if not sequences then
        return
    end

    -- Mostly the same as s-fonts-tables so we should make a helper.

    local series = { }
    local stack  = { }
    local max    = 0

    local function add(v)
        local n = #stack
        if n > max then
            max = n
        end
        series[#series+1] = { v, unpack(stack) }
    end

    local function make(tree)
        for k, v in sortedhash(tree) do
            if k == "ligature" then
                add(v)
            elseif tonumber(v) then
                insert(stack,k)
                add(v)
                remove(stack)
            else
                insert(stack,k)
                make(v)
                remove(stack)
            end
        end
    end

    for i=1,#sequences do
        local sequence = sequences[i]
        if sequence.type == "gsub_ligature" then
            local steps = sequence.steps
            for i=1,#steps do
                local step     = steps[i]
                local coverage = step.coverage
                if coverage then
                    make(coverage)
                end
            end
        end
    end

    return series, max
end

function moduledata.fonts.features.showallligatures(specification)
    specification      = interfaces.checkedspecification(specification)
    local id, cs       = fonts.definers.internal(specification,"<module:fonts:features:font>")
    local tfmdata      = fonts.hashes.identifiers[id]
    local allligatures,
          max          = collectligatures(tfmdata)
    local characters   = tfmdata.characters
    local descriptions = tfmdata.descriptions
    if #allligatures > 0 then
        context.starttabulate { "|T|" .. string.rep("|",max) .. "|T|T|" }
        for i=1,#allligatures do
            local s = allligatures[i]
            local n = #s
            local u = s[1]
            local c = characters[u]
            local d = descriptions[u]
            NC()
            context("%U",u)
            NC()
            context("\\setfontid%i\\relax",id)
            context.char(u)
            NC()
            context("\\setfontid%i\\relax",id)
            for i=2,n do
                context.char(s[i])
                NC()
            end
            for i=n+1,max do
                NC()
            end
            context(d.name)
            NC()
            context(c.tounicode)
            NC()
            NR()
        end
        context.stoptabulate()
    else
        context("no ligatures found")
        context.par()
    end
end


function moduledata.fonts.features.showallfeatures(specification)
    specification   = interfaces.checkedspecification(specification)
    local id, cs    = fonts.definers.internal(specification,"<module:fonts:features:font>")
    local tfmdata   = fonts.hashes.identifiers[id]
    local sequences = tfmdata.resources.sequences

    context.starttabulate { "|T|T|Tc|T|T|Tp|" }

    NC() bold("\\letterhash")
    NC() bold("type")
    NC() bold("\\letterhash steps")
    NC() bold("feature")
    NC() bold("script")
    NC() bold("language")
    NC() NR()
    context.HL()

    for i=1,#sequences do
        local s = sequences[i]
        local features = s.features
        if features then
            local done1 = false
            NC() context(i)
            NC() context(s.type)
            NC() context(s.nofsteps)
            for feature, scripts in table.sortedhash(features) do
                NC()
                if done1 then
                    NC() NC() NC()
                else
                    context(feature)
                    done1 = true
                end
                local done2 = false
                for script, languages in table.sortedhash(scripts) do
                    if done2 then
                        NC() NC() NC() NC()
                    else
                        done2 = true
                    end
                    NC() context(script)
                    NC() context("% t",table.sortedkeys(languages))
                    NC() NR()
                end
            end
        else
            NC() context(i)
            NC() context(s.type)
            NC() context(s.nofsteps)
            NC() NC() NC() NC() NR()
        end
    end

    context.stoptabulate()
end

local function collect(tfmdata,id,specification,feature)
    local validlookups, lookuplist = fonts.handlers.otf.collectlookups(
        tfmdata.shared.rawdata,
        feature,
        specification.script or "math",
        specification.language or "dflt"
    )
    if lookuplist then
        local descriptions = tfmdata.descriptions
        for i=1,#lookuplist do
            local lookup = lookuplist[i]
            if lookup.type == "gsub_single" then
                local steps = lookup.steps
                context.startsubject { title = feature }
                context.starttabulate { "|T|||T|" }
                for i=1,lookup.nofsteps do
                    local c = steps[i].coverage
                    for k, v in table.sortedhash(c) do
                        NC() context(descriptions[k].name)
                        NC() context.showfontidchar(id,k)
                        NC() context.showfontidchar(id,v)
                        NC() context(descriptions[v].name)
                        NC() NR()
                    end
                end
                context.stoptabulate()
                context.stopsubject()
            elseif lookup.type == "gsub_alternate" then
                local steps = lookup.steps
                context.startsubject { title = feature }
                context.starttabulate { "|T|||Tp|" }
                for i=1,lookup.nofsteps do
                    local c = steps[i].coverage
                    for k, v in table.sortedhash(c) do
                        NC() context(descriptions[k].name)
                        NC() context.showfontidchar(id,k)
                        NC()
                        for i=1,#v do
                            if i > 1 then context(" ") end
                            context.showfontidchar(id,v[i])
                        end
                        NC()
                        for i=1,#v do
                            if i > 1 then context(" ") end
                            context(descriptions[v[i]].name)
                        end
                        NC() NR()
                    end
                end
                context.stoptabulate()
                context.stopsubject()
            end
        end
    end
end

function moduledata.fonts.features.showsubstitutions(specification)
    specification = interfaces.checkedspecification(specification)
    local id, cs  = fonts.definers.internal(specification,"<module:fonts:features:font>")
    local tfmdata = fonts.hashes.identifiers[id]
    local feature = specification.feature
    if feature == "*" then
        local features = tfmdata.shared.rawdata.resources.features
        for k in table.sortedhash(features.gsub) do
            collect(tfmdata,id,specification,k)
        end
    else
        collect(tfmdata,id,specification,feature)
    end
end

-- moduledata.fonts.features.showsubstitutions { name = "xcharter-math.otf", feature = "cv06", script = "math", language = "dflt" }
-- moduledata.fonts.features.showsubstitutions { name = "xcharter-math.otf", feature = "*",    script = "math", language = "dflt" }

