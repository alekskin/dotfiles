return {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    dependencies = {
        "nvim-treesitter/nvim-treesitter-context",
    },
    -- the `main` branch does not support lazy-loading
    lazy = false,
    build = ":TSUpdate",
    config = function()
        local treesitter = require("nvim-treesitter")
        local treesitter_context = require("treesitter-context")

        -- parsers to always keep installed (installs asynchronously, no-op if present)
        treesitter.install({ "javascript", "typescript", "java", "lua", "vim", "vimdoc", "kotlin" })

        -- highlighting is Neovim's now: opt in per buffer, installing the parser on demand
        vim.api.nvim_create_autocmd("FileType", {
            group = vim.api.nvim_create_augroup("aleks_treesitter", { clear = true }),
            callback = function(args)
                local lang = vim.treesitter.language.get_lang(args.match)
                if not lang then
                    return
                end

                local function start()
                    pcall(vim.treesitter.start, args.buf, lang)
                end

                if vim.tbl_contains(treesitter.get_installed("parsers"), lang) then
                    start()
                elseif vim.tbl_contains(treesitter.get_available(), lang) then
                    treesitter.install({ lang }):await(start)
                end
            end,
        })

        -- shows current context (e.g. function. block)
        treesitter_context.setup({
            enable = false, -- Enable this plugin (Can be enabled/disabled later via commands)
            max_lines = 1, -- How many lines the window should span. Values <= 0 mean no limit.
            min_window_height = 0, -- Minimum editor window height to enable context. Values <= 0 mean no limit.
            line_numbers = true,
            multiline_threshold = 20, -- Maximum number of lines to show for a single context
            trim_scope = "outer", -- Which context lines to discard if `max_lines` is exceeded. Choices: 'inner', 'outer'
            mode = "cursor", -- Line used to calculate context. Choices: 'cursor', 'topline'
            -- Separator between context and content. Should be a single character string, like '-'.
            -- When separator is set, the context will only show up when there are at least 2 lines above cursorline.
            separator = nil,
            zindex = 20, -- The Z-index of the context window
            on_attach = nil, -- (fun(buf: integer): boolean) return false to disable attaching
        })
    end,
}
