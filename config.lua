Config = {}

Config.VehicleLists = {
    ['list1'] = {
        { model = "scorcher", name = "Scorcher", price = 100, backgroundImage = "images/scorcher.webp" },
        { model = "bmx",      name = "BMX",      price = 60,  backgroundImage = "images/bmx.webp" },
        { model = "cruiser",  name = "Cruiser",  price = 120, backgroundImage = "images/cruiser.webp" },
        { model = "bmx",      name = "BMX",      price = 60,  backgroundImage = "images/bmx.webp" }
    },
    ['list2'] = {
        { model = "sultan", name = "Sultan", price = 500, backgroundImage = "images/Sultan.webp" },
        { model = "blista", name = "Blista", price = 300, backgroundImage = "images/blista.webp" }
    }
}

Config.Paystations = {
    {
        id = 1,
        model = 'prop_park_ticket_01',
        coords = vector3(105.41, -1085.49, 28.2),
        rotation = vector3(0.0, 0.0, 159.45),
        heading = 159.85,
        spawnLoc = vector4(104.29, -1078.78, 29.19, 335.62),
        vehicleList = 'list1',
        blip = {
            enabled = true,
            sprite = 677,
            color = 2,
            scale = 0.8,
            name = "Pay Station"
        }
    },
    -- {
    --     id = 2,
    --     model = 'prop_park_ticket_01',
    --     coords = vector3(108.05, -1078.62, 28.19),
    --     rotation = vector3(0.0, 0.0, 159.85),
    --     heading = 159.85,
    --     spawnLoc = vector4(104.29, -1078.78, 29.19, 335.62),
    --     vehicleList = 'list1',
    --     blip = {
    --         enabled = true,
    --         sprite = 677,
    --         color = 2,
    --         scale = 0.8,
    --         name = "Pay Station"
    --     }
    -- },
}

Config.Interactsettings = {
    interactionDistance = 3.0,
    drawDistance = 25.0,
    removeDistance = 25.0
}

Config.Cam = {
    distance = 0.8
}

Config.givekeyevennt = {
    mode = 'client',
    event = 'vehiclekeys:client:SetOwner'
}
