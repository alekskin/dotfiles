return {
    "stevearc/conform.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        local conform = require("conform")

        conform.setup({
            formatters_by_ft = {
                javascript = { "prettier" },
                typescript = { "prettier" },
                javascriptreact = { "prettier" },
                typescriptreact = { "prettier" },
                svelte = { "prettier" },
                css = { "prettier" },
                html = { "prettier" },
                json = { "prettier" },
                yaml = { "prettier" },
                markdown = { "prettier" },
                -- graphql = { "prettier" },
                lua = { "stylua" },
                c = { "clang-format" },
            },
            format_on_save = {
                lsp_fallback = false,
                async = true,
                timeout_ms = 10000,
            },
        })

        vim.keymap.set({ "n", "v" }, "<leader>lf", function()
            conform.format({
                lsp_fallback = false,
                async = true,
                timeout_ms = 10000,
            })
        end, { desc = "Format file or range (in visual mode)" })
    end,
}
