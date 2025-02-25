# notes.nvim

## Setup

Install [notes](https://github.com/cynumini/notes) and make sure it is available in $PATH.

Using lazy.nvim

```lua
return {
	"cynumini/notes.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	opts = {
		path = "~/notes"
	},
}
```

You also need to install [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for `:NotesSearch'.

Example setup for [blink.cmp](https://github.com/Saghen/blink.cmp).

```lua
return {
	'saghen/blink.cmp',
	dependencies = 'rafamadriz/friendly-snippets',
	version = '*',
	opts = {
		keymap = { preset = 'default' },
		sources = {
			default = {
				"lsp", "path", "snippets", "buffer", "omni", "notes"
			},
			providers = {
				notes = {
					name = 'notes',
					module = 'notes.blink',
				},
			},
		},
	}
}
```

Next, add this shortcut.

```lua
vim.keymap.set("n", "<leader>no", ":NotesSearch<CR>")
```

And add these shortcuts to `~/.config/nvim/after/ftplugin/markdown.lua`.

```lua
vim.keymap.set("n", "<leader>nd", ":NotesDo<CR>", { buffer = 0 })
vim.keymap.set("v", "<leader>ns", ":NotesSortTasks<CR>", { buffer = 0 })
vim.keymap.set("n", "<CR>", ":NotesOpenLink<CR>", { buffer = 0 })
```
