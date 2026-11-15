source      = "shaders/VTHeatVision.hlsl"
techniques  =
    [
        {
            name                                = "SFXVTHeatVision"
            vertex_shader                       = "SFXBasicVS"
            pixel_shader                        = "SFXVTHeatVisionPS"
            depth_test                          = always
            depth_write                         = false
            cull_mode                           = none
        }
    ]
