local isMenuOpened = false
local favoriteEmotes = {}
emoteCategories = nil
local currentProps = {}
local lastPropRemovalTime = 0
local PlayerPedPreview = nil
local isPreviewActive = false
local previewPed = nil
local isPreviewEnabled = false
local currentPreviewEmote = nil
local isOnEmoteButton = false
local currentEmoteData = nil

function LoadFavorites()
    local favoritesJson = GetResourceKvpString('pemotes_favorites')
    if favoritesJson then
        local favorites = json.decode(favoritesJson)
        if favorites and type(favorites) == 'table' then
            favoriteEmotes = favorites
        else
            favoriteEmotes = {}
        end
    else
        favoriteEmotes = {}
    end
end

function SaveFavorites()
    local favoritesJson = json.encode(favoriteEmotes)
    SetResourceKvp('pemotes_favorites', favoritesJson)
end

Citizen.CreateThread(function()
    LoadFavorites()
end)

RMenu.Add('emoteMenu', 'main', RageUI.CreateMenu("", "Choisissez une catégorie", 1350, 0, "bannerAnim", "interaction_bgd2"))
RMenu:Get('emoteMenu', 'main').Closed = function()
    isMenuOpened = false
end

RMenu.Add('emoteMenu', 'Favoris', RageUI.CreateSubMenu(RMenu:Get('emoteMenu', 'main'), ""))
RMenu.Add('emoteMenu', 'FavorisOptions', RageUI.CreateSubMenu(RMenu:Get('emoteMenu', 'Favoris'), ""))

local selectedFavoriteIndex = nil
function GenerateAnimationId(label)
    local id = string.lower(label)
    id = id:gsub("[èéêë]", "e")
    id = id:gsub("[àáâãäå]", "a")
    id = id:gsub("[ìíîï]", "i")
    id = id:gsub("[òóôõö]", "o")
    id = id:gsub("[ùúûü]", "u")
    id = id:gsub("[^%w]", "")
    return id
end

Citizen.CreateThread(function()
    local anims = LoadResourceFile(GetCurrentResourceName(), "animations.lua")
    if anims then
        local func, err = load(anims)
        if func then
            local success, result = pcall(func)
            if success then
                for category, animations in pairs(result) do
                    if type(animations) == "table" then
                        for _, anim in ipairs(animations) do
                            if type(anim) == "table" then
                                anim.id = GenerateAnimationId(anim.label)
                            end
                        end
                    end
                end
                emoteCategories = result

                table.insert(emoteCategories["Humeurs"], 1, {label = "Normal", resetMood = true})

                table.insert(emoteCategories["Démarches"], 1, {label = "Normal", resetWalk = true})

                local orderedCategories = {
                    "Animations",
                    "Animations de danses",
                    "Props animations",
                    "Humeurs",
                    "Démarches"
                }

                for _, mainCategory in ipairs(orderedCategories) do
                    local data = emoteCategories[mainCategory]
                    if data then
                        RMenu.Add('emoteMenu', mainCategory, RageUI.CreateSubMenu(RMenu:Get('emoteMenu', 'main'), "", mainCategory))

                        if mainCategory == "Animations" then
                            local subCategories = {}
                            for key, value in pairs(data) do
                                if type(key) == "string" and type(value) == "table" then
                                    table.insert(subCategories, key)
                                end
                            end
                            table.sort(subCategories)

                            for _, subCategory in ipairs(subCategories) do
                                RMenu.Add('emoteMenu', subCategory, RageUI.CreateSubMenu(RMenu:Get('emoteMenu', 'Animations'), "", subCategory))
                            end
                        end
                    else
                    end
                end

            else
            end
        else
        end
    else
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsControlJustPressed(0, 288) then
            OpenEmoteMenu()
        end
    end
end)

function OpenEmoteMenu()
    if isMenuOpened then
        isMenuOpened = false
        RageUI.CloseAll()
        return
    else
        isMenuOpened = true
        RageUI.Visible(RMenu:Get('emoteMenu', 'main'), true)
    end
end

Citizen.CreateThread(function()
    while true do
        if isMenuOpened then
            RageUI.IsVisible(RMenu:Get('emoteMenu', 'main'), function()
                RageUI.Button("Favoris ⭐️ ", nil, {RightLabel = "→"}, true, {
                    onActive = function()
                        if isPreviewEnabled then
                            StopEmotePreview()
                        end
                    end
                }, RMenu:Get('emoteMenu', 'Favoris'))
                RageUI.Button("Animations 🎬", nil, {RightLabel = "→"}, true, {
                    onActive = function()
                        if isPreviewEnabled then
                            StopEmotePreview()
                        end
                    end
                }, RMenu:Get('emoteMenu', 'Animations'))
                RageUI.Button("Animations de danses 🕺", nil, {RightLabel = "→"}, true, {}, RMenu:Get('emoteMenu', 'Animations de danses'))
                RageUI.Button("Props animations 🌹", nil, {RightLabel = "→"}, true, {}, RMenu:Get('emoteMenu', 'Props animations'))
                RageUI.Button("Humeurs 😏", nil, {RightLabel = "→"}, true, {}, RMenu:Get('emoteMenu', 'Humeurs'))
                RageUI.Button("Démarches 🚶", nil, {RightLabel = "→"}, true, {}, RMenu:Get('emoteMenu', 'Démarches'))
                RageUI.Button("~o~Supprimer props", "Supprime les accessoires attachés à votre personnage.", {}, true, {
                    onSelected = function()
                        local currentTime = GetGameTimer()
                        if currentTime - lastPropRemovalTime >= 5000 then
                            RemoveAllProps()
                            ShowNotification("~g~Tous les props ont été supprimés.")
                            lastPropRemovalTime = currentTime
                        else
                            local remainingTime = math.ceil((5000 - (currentTime - lastPropRemovalTime)) / 1000)
                            ShowNotification("~r~Veuillez patienter " .. remainingTime .. " secondes avant de réutiliser cette action.")
                        end
                    end
                })
                RageUI.Button("~r~Annuler l'animation", "Annule l'animation en cours.", {}, true, {
                    onSelected = function()
                        local playerPed = PlayerPedId()
                        ClearPedTasks(playerPed)
                        RemoveAllProps()
                    end
                })
            end)
            RageUI.IsVisible(RMenu:Get('emoteMenu', 'Favoris'), function()
                if #favoriteEmotes > 0 then
                    for index, emote in ipairs(favoriteEmotes) do
                        RageUI.Button(emote.label, nil, {RightLabel = "→"}, true, {
                            onSelected = function()
                                selectedFavoriteIndex = index
                            end
                        }, RMenu:Get('emoteMenu', 'FavorisOptions'))
                    end
                else
                    RageUI.Separator("~r~Aucune animation en favoris")
                end
            end)
            RageUI.IsVisible(RMenu:Get('emoteMenu', 'FavorisOptions'), function()
                if selectedFavoriteIndex and favoriteEmotes[selectedFavoriteIndex] then
                    local emote = favoriteEmotes[selectedFavoriteIndex]
                    RageUI.Button("Jouer l'animation", nil, {}, true, {
                        onSelected = function()
                            PlayEmote(emote)
                        end
                    })
                    RageUI.Button("~r~Supprimer des favoris", nil, {}, true, {
                        onSelected = function()
                            RemoveFromFavorites(selectedFavoriteIndex)
                            selectedFavoriteIndex = nil
                            RageUI.GoBack()
                        end
                    })
                else
                    RageUI.Separator("~r~Aucun favori sélectionné")
                end
            end)

            local orderedCategories = {
                "Animations",
                "Animations de danses",
                "Props animations",
                "Humeurs",
                "Démarches"
            }

            for _, mainCategory in ipairs(orderedCategories) do
                local data = emoteCategories[mainCategory]
                if data then
                    RageUI.IsVisible(RMenu:Get('emoteMenu', mainCategory), function()
                        if mainCategory == "Animations" then
                            local subCategories = {}
                            local individualAnimations = {}

                            for key, value in pairs(data) do
                                if type(key) == "string" and type(value) == "table" then
                                    table.insert(subCategories, key)
                                elseif type(value) == "table" and value.label then
                                    table.insert(individualAnimations, value)
                                end
                            end
                            table.sort(subCategories)
                            for _, subCategory in ipairs(subCategories) do
                                RageUI.Button(subCategory, nil, {RightLabel = "→"}, true, {}, RMenu:Get('emoteMenu', subCategory))
                            end
                            for _, emote in ipairs(individualAnimations) do
                                if emote.mood or emote.walk or emote.resetMood or emote.resetWalk then
                                    RageUI.Button(emote.label, nil, {}, true, {
                                        onSelected = function()
                                            PlayEmote(emote)
                                        end
                                    })
                                else
                                    RageUI.Button(emote.label, "/e " .. emote.id, {}, true, {
                                        onSelected = function()
                                            PlayEmote(emote)
                                        end,
                                        onActive = function()
                                            isOnEmoteButton = true
                                            if IsControlJustPressed(0, 217) then
                                                AddToFavorites(emote)
                                            end
                                            if not isPreviewEnabled then
                                                StartEmotePreview()
                                            end
                                            if previewPed and currentPreviewEmote ~= emote.label then
                                                currentPreviewEmote = emote.label
                                                currentEmoteData = emote
                                                PlayEmote(emote, true)
                                            end
                                        end,
                                        onExit = function()
                                            isOnEmoteButton = false
                                            currentEmoteData = nil
                                        end
                                    })
                                end
                            end
                        else
                            for _, emote in ipairs(data) do
                                if emote.mood or emote.walk or emote.resetMood or emote.resetWalk then
                                    RageUI.Button(emote.label, nil, {}, true, {
                                        onSelected = function()
                                            PlayEmote(emote)
                                        end
                                    })
                                else
                                    RageUI.Button(emote.label, "/e " .. emote.id, {}, true, {
                                        onSelected = function()
                                            PlayEmote(emote)
                                        end,
                                        onActive = function()
                                            isOnEmoteButton = true
                                            if IsControlJustPressed(0, 217) then
                                                AddToFavorites(emote)
                                            end
                                            if not isPreviewEnabled then
                                                StartEmotePreview()
                                            end
                                            if previewPed and currentPreviewEmote ~= emote.label then
                                                currentPreviewEmote = emote.label
                                                currentEmoteData = emote
                                                PlayEmote(emote, true)
                                            end
                                        end,
                                        onExit = function()
                                            isOnEmoteButton = false
                                            currentEmoteData = nil
                                        end
                                    })
                                end
                            end
                        end
                    end)
                end
            end

            if emoteCategories["Animations"] then
                local subCategories = {}
                for key, value in pairs(emoteCategories["Animations"]) do
                    if type(key) == "string" and type(value) == "table" then
                        table.insert(subCategories, key)
                    end
                end
                table.sort(subCategories)

                for _, subCategory in ipairs(subCategories) do
                    RageUI.IsVisible(RMenu:Get('emoteMenu', subCategory), function()
                        for _, emote in ipairs(emoteCategories["Animations"][subCategory]) do
                            if emote.mood or emote.walk or emote.resetMood or emote.resetWalk then
                                RageUI.Button(emote.label, nil, {}, true, {
                                    onSelected = function()
                                        PlayEmote(emote)
                                    end
                                })
                            else
                                RageUI.Button(emote.label, "/e " .. emote.id, {}, true, {
                                    onSelected = function()
                                        PlayEmote(emote)
                                    end,
                                    onActive = function()
                                        isOnEmoteButton = true
                                        if IsControlJustPressed(0, 217) then
                                            AddToFavorites(emote)
                                        end
                                        if not isPreviewEnabled then
                                            StartEmotePreview()
                                        end
                                        if previewPed and currentPreviewEmote ~= emote.label then
                                            currentPreviewEmote = emote.label
                                            currentEmoteData = emote
                                            PlayEmote(emote, true)
                                        end
                                    end,
                                    onExit = function()
                                        isOnEmoteButton = false
                                        currentEmoteData = nil
                                    end
                                })
                            end
                        end
                    end)
                end
            end

        end
        Citizen.Wait(0)
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsControlJustPressed(0, 73) then
            local playerPed = PlayerPedId()
            ClearPedTasks(playerPed)
            RemoveAllProps()
        end
    end
end)

function StartEmotePreview()
    if isPreviewEnabled then return end

    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)

    previewPed = ClonePed(playerPed, heading, true, false)
    SetEntityCoords(previewPed, coords.x + 1.5, coords.y, coords.z - 1.0)
    FreezeEntityPosition(previewPed, true)

    SetEntityAlpha(previewPed, 200, false)
    SetEntityInvincible(previewPed, true)
    SetEntityCollision(previewPed, false, false)

    NetworkSetEntityInvisibleToNetwork(previewPed, true)
    SetEntityNoCollisionEntity(PlayerPedId(), previewPed, true)
    SetEntityOnlyDamagedByPlayer(previewPed, false)
    SetEntityCanBeDamaged(previewPed, false)

    isPreviewEnabled = true
end

function StopEmotePreview()
    if previewPed then
        ClearPedTasks(previewPed)
        DeleteEntity(previewPed)
        previewPed = nil
    end
    isPreviewEnabled = false
    currentPreviewEmote = nil
end

function PlayEmote(emote, isPreview)
    local targetPed = isPreview and previewPed or PlayerPedId()
    
    if not DoesEntityExist(targetPed) then return end
    
    ClearPedTasks(targetPed)
    
    if emote.anim then
        RequestAnimDict(emote.anim)
        while not HasAnimDictLoaded(emote.anim) do
            Citizen.Wait(0)
        end
        
        if not isPreview then
            RemoveAllProps()
        end
        
        TaskPlayAnim(targetPed, emote.anim, emote.animName, 8.0, -8.0, -1, emote.flag or 48, 0, false, false, false)
        
    elseif emote.mood then
        SetFacialIdleAnimOverride(targetPed, emote.mood, 0)
    elseif emote.walk then
        RequestAnimSet(emote.walk)
        while not HasAnimSetLoaded(emote.walk) do
            Citizen.Wait(0)
        end
        SetPedMovementClipset(targetPed, emote.walk, 0.2)
    elseif emote.resetMood then
        ClearFacialIdleAnimOverride(targetPed)
    elseif emote.resetWalk then
        ResetPedMovementClipset(targetPed, 0)
    end
end

function AddToFavorites(emote)
    for _, favorite in ipairs(favoriteEmotes) do
        if favorite.label == emote.label then
            ShowNotification("~r~Cette animation est déjà dans vos favoris.")
            return
        end
    end
    table.insert(favoriteEmotes, emote)
    ShowNotification("~g~Animation ajoutée aux favoris.")
    SaveFavorites()
end

function RemoveFromFavorites(index)
    if favoriteEmotes[index] then
        table.remove(favoriteEmotes, index)
        ShowNotification("~r~Animation retirée des favoris.")
        SaveFavorites()
    else
        ShowNotification("~r~Impossible de supprimer le favori.")
    end
end

function RemoveAllProps()
    local playerPed = PlayerPedId()
    for _, prop in ipairs(currentProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
    currentProps = {}
end

function KeyboardInput(textEntry, inputText, maxLength)
    AddTextEntry('FMMC_KEY_TIP1', textEntry)
    DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP1", "", inputText, "", "", "", maxLength)
    blockinput = true
    while UpdateOnscreenKeyboard() ~= 1 and UpdateOnscreenKeyboard() ~= 2 do
        Wait(0)
    end
    if UpdateOnscreenKeyboard() ~= 2 then
        local result = GetOnscreenKeyboardResult()
        Wait(500)
        blockinput = false
        return result
    else
        Wait(500)
        blockinput = false
        return nil
    end
end

function ShowNotification(text)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(text)
    DrawNotification(false, true)
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if (not isMenuOpened or not isOnEmoteButton) and isPreviewEnabled then
            StopEmotePreview()
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)
        if isPreviewEnabled and currentPreviewEmote and previewPed and currentEmoteData then
            if not IsEntityPlayingAnim(previewPed, currentEmoteData.anim, currentEmoteData.animName, 3) then
                PlayEmote(currentEmoteData, true)
            end
        end
    end
end)

RegisterCommand("e", function(source, args, rawCommand)
    if #args < 1 then return end
    local requestedId = args[1]

    for _, category in pairs(emoteCategories) do
        if type(category) == "table" then
            for _, anim in ipairs(category) do
                if type(anim) == "table" and anim.id == requestedId then
                    PlayEmote(anim)
                    return
                end
            end
        end
    end
    
    ShowNotification("~r~Animation non trouvée: " .. requestedId)
end, false)