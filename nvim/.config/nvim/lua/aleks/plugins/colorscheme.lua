return {
    {
        "tjdevries/colorbuddy.nvim",
        priority = 1000,
        lazy = false,
        config = function()
            vim.cmd("colorscheme gruvbox-minor")
        end,
    },
    "cocopon/iceberg.vim",
    {
        "AlexvZyl/nordic.nvim",
        priority = 1000,
        config = function()
            local nordic = require("nordic")
            local black = "#171717"

            nordic.setup({
                on_palette = function(palette)
                    palette.black0 = black
                    return palette
                end,
            })

            -- nordic.load()
        end,
    },
    -- "rktjmp/lush.nvim",
    {
        "rose-pine/neovim",
        name = "rose-pine",
        config = function()
            vim.cmd("colorscheme rose-pine")
        end,
    },
    "jesseleite/nvim-noirbuddy",
    "rebelot/kanagawa.nvim",
    "Shatur/neovim-ayu",
    -- "RRethy/base16-nvim",
    "ntk148v/komau.vim",
    { "catppuccin/nvim", name = "catppuccin" },
    "LuRsT/austere.vim",
    "ricardoraposo/gruvbox-minor.nvim",
    {
        "vague2k/vague.nvim",
        config = function()
            -- require("vague").setup({})
            -- vim.cmd("colorscheme vague")
        end,
    },
    {
        "omacom-io/lumon.nvim",
        config = function()
            -- vim.cmd("colorscheme lumon")
        end,
    },
}
