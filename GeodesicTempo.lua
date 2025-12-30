-- GeodesicTempo

function beat2ms(beat) return beat * (60000 / getTempo()) end

local CYCLE_CONFIG = {0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0}
local cycleNames = {"1/16", "1/16 D", "1/8", "1/8 D", "1/4", "1/4 D", "1/2", "1/2 D", "1/1"}
local CURVE_CONFIG = {1/4, 1/3, 1/2, 1, 2, 3, 4}
local curveNames = {"^1/4", "^1/3", "^1/2", "Linear", "^2", "^3", "^4"}

-- UI
local cycleMenu = Menu("Cycle", cycleNames, 5)
local modeMenu = Menu("Mode", {"Pull-Pull", "Push-Push", "Pull-Push", "Push-Pull"}, 1)
local curveMenu = Menu("Curve", curveNames, 4)
local amountKnob = Knob("Amount", 0, 0, 0.25)
local asymKnob = Knob("Asymmetry", 0.5, 0.25, 0.75)
local invert = OnOffButton("Invert", false)
local lengthMenu = Menu("NoteLength", {"Fixed (Stable)", "Flex (Dynamic)"}, 1)

local latency = NumBox("Latency", 0, 0, 1000)
latency.unit, latency.readOnly, latency.width = Unit.MilliSeconds, true, 120
local tension = NumBox("Tension", 0, 0, 100)
tension.unit, tension.readOnly, tension.width = Unit.Percent, true, 140

-- Note management
local InitialOffsets, ScheduledNoteOnTimes = {}, {}

function onTransport(playing)
    if not playing then tension.value = 0 end
end

function calculateCurrentLfoState()
    local cycleDuration = CYCLE_CONFIG[cycleMenu.value]
    local mode = modeMenu.value
    local maxDelayAmount = amountKnob.value * cycleDuration
    
    local cycleMultiplier = (mode <= 2) and 1 or 2
    local rawPhase = (getBeatTime() / (cycleDuration * cycleMultiplier)) % 1.0
    
    local skewPoint = asymKnob.value
    local skewedPhase = (rawPhase < skewPoint) and (rawPhase / skewPoint) or ((rawPhase - skewPoint) / (1.0 - skewPoint))

    local lfoAmplitude = (mode <= 2) and (1.0 - math.abs(skewedPhase * 2.0 - 1.0)) or (rawPhase < skewPoint and skewedPhase or 1.0 - skewedPhase)
    if invert.value then lfoAmplitude = 1.0 - lfoAmplitude end

    local isPushMode = (mode % 2 == 0)
    local baseOffset, direction = isPushMode and 1 or 0, isPushMode and -1 or 1
    
    local finalOffset = (baseOffset + (direction * (lfoAmplitude ^ CURVE_CONFIG[curveMenu.value]))) * maxDelayAmount
    
    return finalOffset, lfoAmplitude
end

function onNote(e)
    local currentOffset, lfoAmplitude = calculateCurrentLfoState()
    
    InitialOffsets[e.id] = currentOffset
    ScheduledNoteOnTimes[e.id] = getBeatTime() + currentOffset
    
    latency.value = beat2ms(amountKnob.value * CYCLE_CONFIG[cycleMenu.value])
    tension.value = lfoAmplitude * amountKnob.value * 400
    
    postEvent(e, beat2ms(currentOffset))
end

function onRelease(e)
    local initialOffset = InitialOffsets[e.id]
    if initialOffset == nil then return end

    local currentTime = getBeatTime()
    local finalReleaseOffset = initialOffset

    if currentTime > 0 then
        local currentLfoOffset, lfoAmplitude = calculateCurrentLfoState()
        tension.value = lfoAmplitude * amountKnob.value * 400
        
        if lengthMenu.value == 2 then
            local minimumSafeOffset = ScheduledNoteOnTimes[e.id] - currentTime
            finalReleaseOffset = math.max(currentLfoOffset, minimumSafeOffset)
        end
    else
        tension.value = 0
    end

    postEvent(e, beat2ms(finalReleaseOffset))
    
    InitialOffsets[e.id], ScheduledNoteOnTimes[e.id] = nil, nil
end