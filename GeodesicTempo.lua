-- GeodesicTempo v2.2

local WARP_SENS = 0.6
local CURVE_EXP_BASE = 2.5
local LATENCY_SCAN_STEPS = 64

function beat2ms(beat) return beat * (60000 / getTempo()) end

local CYCLE_CONFIG = {0.25, 0.375, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0}
local cycleNames = {"1/16", "1/16 D", "1/8", "1/8 D", "1/4", "1/4 D", "1/2", "1/2 D", "1/1"}
local modeNames = {"OneWay", "Ping-Pong"}

local cycleMenu     = Menu("Cycle", cycleNames, 5)
local modeMenu      = Menu("Mode", modeNames, 1)
local lengthMenu    = Menu("NoteLength", {"Fixed", "Flex"}, 1)
local intensityKnob = Knob("Intensity", 0.0, -1.0, 1.0)
local biasKnob      = Knob("Bias", 0.0, -1.0, 1.0)
local dynamicsKnob  = Knob("Dynamics", 0.5, 0.0, 1.0)

local latencyDisplay = NumBox("Latency", 0, 0, 1000)
latencyDisplay.unit, latencyDisplay.readOnly = Unit.MilliSeconds, true

local backLatencyDisplay = NumBox("BackLatency", 0, 0, 1000)
backLatencyDisplay.unit, backLatencyDisplay.readOnly = Unit.MilliSeconds, true

local InitialOffsets = {}
local ScheduledNoteOnTimes = {}
local cachedLatency = 0
local needsUpdate = true

local function getWarpedPhase(phase, amount, isReverse, dynamics)
    local dev = amount * (WARP_SENS * dynamics)
    local effAmount = math.max(0, math.min(1, isReverse and (0.5 - dev) or (0.5 + dev)))
    if effAmount == 0.5 then return phase end
   
    local useMirror = (effAmount < 0.5)
    local targetP = useMirror and (1.0 - phase) or phase
    local normA = useMirror and (1.0 - effAmount) or effAmount
    
    local exp = 1.0 + (normA - 0.5) * (CURVE_EXP_BASE * (1.0 + dynamics))
    local res = targetP ^ exp
    return useMirror and (1.0 - res) or res
end

local function getCalculatedState(beatTime, cCycle)
    local pCycle = cCycle * 2
    local pPhaseRaw = (beatTime / pCycle) % 1.0
    local pWarped = getWarpedPhase(pPhaseRaw, biasKnob.value, false, dynamicsKnob.value)
    local pOffset = (pPhaseRaw - pWarped) * pCycle
   
    local cPhaseRaw = (pWarped * 2) % 1.0
    local isReverse = (modeMenu.value == 2) and (pWarped >= 0.5)
    local cWarped = getWarpedPhase(cPhaseRaw, intensityKnob.value, isReverse, dynamicsKnob.value)
    local cOffset = (cPhaseRaw - cWarped) * cCycle
   
    return pOffset + cOffset
end

local function updateBaseLatency()
    local cCycle = CYCLE_CONFIG[cycleMenu.value]
    local pCycle = cCycle * 2
    local maxPush, targetOffset, minDiff = 0, 0, 1e10
    
    for i = 0, LATENCY_SCAN_STEPS do
        local beatTime = (i / LATENCY_SCAN_STEPS) * pCycle
        
        local pPhaseRaw = (beatTime / pCycle) % 1.0
        local pWarped = getWarpedPhase(pPhaseRaw, biasKnob.value, false, dynamicsKnob.value)
        local cPhaseRaw = (pWarped * 2) % 1.0
        
        local totalOff = getCalculatedState(beatTime, cCycle)
        
        if totalOff < maxPush then maxPush = totalOff end
        
        local diff = math.abs(cPhaseRaw - 0.5)
        if diff < minDiff then
            minDiff = diff
            targetOffset = totalOff
        end
    end
    
    cachedLatency = math.abs(maxPush)
    latencyDisplay.value = beat2ms(cachedLatency)
    backLatencyDisplay.value = beat2ms(math.abs(targetOffset))
    needsUpdate = false
end

local function invalidate() needsUpdate = true end
cycleMenu.changed = invalidate
modeMenu.changed = invalidate
intensityKnob.changed = invalidate
biasKnob.changed = invalidate
dynamicsKnob.changed = invalidate

function onNote(e)
    if needsUpdate then updateBaseLatency() end
    local finalOffset = cachedLatency + getCalculatedState(getBeatTime(), CYCLE_CONFIG[cycleMenu.value])
   
    InitialOffsets[e.id] = finalOffset
    ScheduledNoteOnTimes[e.id] = getBeatTime() + finalOffset
    postEvent(e, beat2ms(finalOffset))
end

function onRelease(e)
    local initialOffset = InitialOffsets[e.id]
    if not initialOffset then return end

    local finalReleaseOffset = initialOffset
    if lengthMenu.value == 2 then
        local currentLfoOffset = cachedLatency + getCalculatedState(getBeatTime(), CYCLE_CONFIG[cycleMenu.value])
        finalReleaseOffset = math.max(currentLfoOffset, ScheduledNoteOnTimes[e.id] - getBeatTime())
    end

    postEvent(e, beat2ms(finalReleaseOffset))
    InitialOffsets[e.id], ScheduledNoteOnTimes[e.id] = nil, nil
end
