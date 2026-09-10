if not _G.charSelectExists then return end

E_MODEL_PARTICLE_RING = smlua_model_util_get_id('jers_wario_ring_particle_geo')

gPlayerObjects = {}
for i = 0, (MAX_PLAYERS - 1) do
    gPlayerObjects[i] = nil
    gPlayerSyncTable[i].jwarRingFrame = 0
end

------------

local ringScale = 1.2

define_custom_obj_fields({
    oPlayerIndex = 'u32',
})

function jwar_ring_particle_anim(node, matStackIndex)
    local asSwitchNode = cast_graph_node(node)
    local m = geo_get_mario_state()
    local s = gPlayerSyncTable[m.playerIndex]
    local toNode = s.jwarRingFrame
    if s.jwarRingFrame > 10 then
        s.jwarRingFrame = 1
    else
        s.jwarRingFrame = s.jwarRingFrame + 1
    end
    asSwitchNode.selectedCase = toNode
end

local function ring_particle_init(o)
    o.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    o.hookRender = 1
    obj_scale(o, ringScale)
    o.oFaceAngleRoll = 0 - degrees_to_sm64(90)
    cur_obj_hide()
end

local function ring_particle_loop(o)
    local m = gMarioStates[o.oPlayerIndex]

    -- if the player is off screen, hide the obj
    if m.marioBodyState.updateTorsoTime ~= gMarioStates[0].marioBodyState.updateTorsoTime then
        cur_obj_hide()
        return
    end

    -- update pallet
    local np = gNetworkPlayers[o.oPlayerIndex]
    if np ~= nil then
        o.globalPlayerIndex = np.globalIndex
    end

    -- check if this should be activated
    if obj_is_hidden(o) ~= 0 then
        cur_obj_unhide()
        obj_set_model_extended(o, E_MODEL_PARTICLE_RING)
        obj_scale(o, ringScale)
    end

    if (m.action == ACT_WAR_SH_BASH or m.action == ACT_WAR_SH_BASH_JUMP) and m.forwardVel >= (bashSpeedBase + 24) then
        cur_obj_unhide()
    else
        cur_obj_hide()
    end
end

local id_bhvRingParticle = hook_behavior(nil, OBJ_LIST_DEFAULT, true, ring_particle_init, ring_particle_loop, "bhvRingParticle")

---@param o Object
local function bhv_coin_drop_init(o)
    o.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    obj_set_billboard(o)

    o.oVelY = random_float() * 10.0 + 30 + o.oCoinUnk110;
    o.oForwardVel = random_float() * 10.0;
    o.oMoveAngleYaw = random_u16();
    cur_obj_become_intangible();

    o.oWallHitboxRadius = 30
    o.oGravity = -400
    o.oBounciness = -70
    o.oDragStrength = 1000
    o.oFriction = 1000
    o.oBuoyancy = 200

    network_init_object(o, true, {
        "globalPlayerIndex"
    })
end

local function bhv_coin_drop_loop(o)
    local nM = nearest_mario_state_to_object(o) or gMarioStates[0]
    local e = gExtraStates[nM.playerIndex]

    cur_obj_update_floor_and_walls();
    cur_obj_if_hit_wall_bounce_away();
    cur_obj_move_standard(-62);

    local sp1C = o.oFloor
    if (sp1C ~= nil) then
        if (o.oMoveFlags & OBJ_MOVE_ON_GROUND ~= 0) then
            o.oSubAction = 1;
        end
        if (o.oSubAction == 1) then
            o.oBounciness = 0;
            if (sp1C.normal.y < 0.9) then
                local sp1A = atan2s(sp1C.normal.z, sp1C.normal.x);
                cur_obj_rotate_yaw_toward(sp1A, 0x400);
            end
        end
    end
    if (o.oTimer == 0) then
        cur_obj_play_sound_2(SOUND_GENERAL_COIN_SPURT_2);
        --cur_obj_play_sound_2(SOUND_GENERAL_COIN_SPURT_EU);
        --cur_obj_play_sound_2(SOUND_GENERAL_COIN_SPURT);
    end
    if (o.oVelY < 0 and o.globalPlayerIndex ~= network_global_index_from_local(0)) then
        cur_obj_become_tangible();
    end
    if (o.oMoveFlags & OBJ_MOVE_LANDED ~= 0) then
        if (o.oMoveFlags & (OBJ_MOVE_ABOVE_DEATH_BARRIER | OBJ_MOVE_ABOVE_LAVA) ~= 0) then
            obj_mark_for_deletion(o);
        end
    end
    if (o.oMoveFlags & OBJ_MOVE_BOUNCE ~= 0) then
        if (o.oCoinUnk1B0 < 5) then
            cur_obj_play_sound_2(SOUND_GENERAL_COIN_DROP);
        end
        o.oCoinUnk1B0 = o.oCoinUnk1B0 + 1;
    end
    if (cur_obj_wait_then_blink(400, 20) ~= 0) then
        obj_mark_for_deletion(o);
    end
    
    if (o.oInteractStatus & INT_STATUS_INTERACTED ~= 0 and (o.oInteractStatus & INT_STATUS_TOUCHED_BOB_OMB == 0)) then
        e.wallet = e.wallet + 1
        --spawn_object(o, MODEL_SPARKLES, bhvGoldenCoinSparkles);
        obj_mark_for_deletion(o);
    end
    o.oInteractStatus = 0;

    o.oAnimState = o.oAnimState + 1
end

id_bhvCoinDrop = hook_behavior(nil, OBJ_LIST_LEVEL, false, bhv_coin_drop_init, bhv_coin_drop_loop, "bhvCoinDrop")

------------

local function on_sync_valid()
    for i = 0, (MAX_PLAYERS - 1) do
        gPlayerObjects[i] = {
            [1] = spawn_non_sync_object(id_bhvRingParticle, E_MODEL_PARTICLE_RING, 0, 0, 0,
            function(o)
                o.oPlayerIndex = i
            end)
        }
    end
end

local function on_object_render(o)
    local m = gMarioStates[o.oPlayerIndex]
    if get_id_from_behavior(o.behavior) == id_bhvRingParticle then
        local rot = (((m.forwardVel - (bashSpeedBase + 18))/3)*1000)

        o.oPosX = m.pos.x
        o.oPosY = m.pos.y + 80
        o.oPosZ = m.pos.z
        --o.oFaceAnglePitch = o.oFaceAnglePitch + rot
        o.oFaceAngleYaw = m.marioObj.header.gfx.angle.y - degrees_to_sm64(90)
    
        -- if the player is off screen, move the obj to the player origin
        if m.marioBodyState.updateTorsoTime ~= gMarioStates[0].marioBodyState.updateTorsoTime then
            --o.oPosX = m.pos.x
            o.oPosY = m.pos.y
            --o.oPosZ = m.pos.z
        end
    
        o.header.gfx.pos.x = o.oPosX
        o.header.gfx.pos.y = o.oPosY
        o.header.gfx.pos.z = o.oPosZ
    end
end

hook_event(HOOK_ON_OBJECT_RENDER, on_object_render)
hook_event(HOOK_ON_SYNC_VALID, on_sync_valid)