# notes.nvim

## Setup

Install [notes](https://github.com/cynumini/notes) and make sure it is available in $PATH.

Using lazy.nvim:

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

You also need to install [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for `:NotesSearch`.

Example setup for [blink.cmp](https://github.com/Saghen/blink.cmp):

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

Next, add this shortcut:

```lua
vim.keymap.set("n", "<leader>no", ":NotesSearch<CR>")
```

And add these shortcuts to `~/.config/nvim/after/ftplugin/markdown.lua`:

```lua
vim.keymap.set("n", "<leader>nd", ":NotesDo<CR>", { buffer = 0 })
vim.keymap.set("v", "<leader>ns", ":NotesSortTasks<CR>", { buffer = 0 })
vim.keymap.set("n", "<CR>", ":NotesOpenLink<CR>", { buffer = 0 })
```

## Usage

After setup you have 4 commands and autocompletion for markdown files.

When you create a new file with notes.nvim, use this pattern: `%Y%m%d%H%M%S-title.md`. Inside this file it inserts YAML frontmatter to make sure a NotesSearch command will show it as `title`.

### NotesSearch

This command will search every markdown file in your opts.path and also parse links inside those files and display them as well. To determine the title of the notes, it uses the YAML frontmatter field title or filename.

After you select notes, it opens or creates the notes you selected.

If you want to crate a note based on your input, not on the match, press `<C-y>` in the search prompt.

### NotesOpenLink

If you have wikilinks in your file, and you call `NotesOpenLink` while the cursor is on the link, it will try to find an existing link with the same title and open it, if there is no link with that title, it will create it instead.

Example of a link:

```markdown
This text with link: [[My other note]].
```

### NotesDo

If you task on the line with markdown task `- [ ] my task` it mark it done or vice versa.

If the task under the cursor have scheduled like this `- [ ] my task scheduled:<2025-03-22 09:08 .+4w>`, it instead of marking it done, it just reschedule it based on recurrence type. In this case the recurrence is `.+4w`. Besides this program supports 3 types of recurrence and 2 types of recurrence unit (days and weeks). To learn more about how they work, I recommend reading this page of the org-mode documentation [8.3.2 Repeated tasks](https://orgmode.org/manual/Repeated-tasks.html). The only difference is that I've only added support for `SCHEDULED` and there is no warning period.

Although there is also the time, it's not used in NotesDo, but only in NotesSortTasks.

Some other examples of tasks with `scheduled`:

- It means that the task will be repeated every 2 days, and if you miss the day, after completion the new `scheduled` will be 1 day after the current day.

```markdown
- [ ] Clean my room scheduled:<2025-02-21 08:00 .+2d>
```

- It mean that task will be repeated every 2 days, and if you miss the day, after completion it will add 2 day to previous `scheduled` until new `scheduled` is greater that currend date.

```markdown
- [ ] Clean my room scheduled:<2025-02-22 08:00 ++2d>
```

- It means that the task will be repeated every 2 days, and it's just adding 2 days to the task's `scheduled` date, no matter what.

```markdown
- [ ] Clean my room scheduled:<2025-02-27 08:00 ++2d>
```

- There is also support for weekly recurrence.

```markdown
- [ ] Buy apples scheduled:<2025-02-20 08:00 ++1w>
```

### NotesSortTasks

This command helps to sort tasks based on the `scheduled` of the task. It uses both time and date in `scheduled`.

Select lines with `V` and then run `:NotesSortTasks`.

Before:

```markdown
- [ ] Clean my room scheduled:<2025-02-26 08:00 .+1d>
- [ ] Do Anki scheduled:<2025-02-24 08:10 .+1d>
- [ ] Buy apples scheduled:<2025-02-24 08:05 .+1d>
```

After:

```markdown
- [ ] Buy apples scheduled:<2025-02-24 08:05 .+1d>
- [ ] Do Anki scheduled:<2025-02-24 08:10 .+1d>
- [ ] Clean my room scheduled:<2025-02-26 08:00 .+1d>
```

### Autocompletion

notes.nvim use wikilinks, so to trigger autocompletion type `[[`, then each next symbol will try to find note with matching title.
