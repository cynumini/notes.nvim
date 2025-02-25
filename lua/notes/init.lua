---@class Notes
---@field path string
---@field notes table<string, string|vim.NIL>
local M = {}

local Path = require("plenary.path")
local Job = require("plenary.job")
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local previewers = require("telescope.previewers")
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"

---@class Opts
---@field path string

---Initialize notes
---@param opts Opts
M.setup = function(opts)
	if opts.path == nil then
		vim.notify("You have to set the path in the notes.nvim setup!", vim.log.levels.ERROR)
		return
	end
	M.path = vim.fn.expand(opts.path)
	vim.api.nvim_create_user_command("NotesSearch", M.search, {})
	vim.api.nvim_create_user_command("NotesOpenLink", M.open_link, {})
	vim.api.nvim_create_user_command("NotesDo", M.do_task, {})
	vim.api.nvim_create_user_command("NotesSortTasks", M.sort_task, { range = "%" })
end

---Update list of notes
---@param sync boolean?
---@param on_finish function?
M.update = function(sync, on_finish)
	sync = sync or true
	---@diagnostic disable-next-line
	local job = Job:new({
		command = 'notes',
		args = { "json", M.path },
		on_stderr = function(_, result, _)
			vim.notify(result, vim.log.levels.ERROR)
		end,
		on_stdout = function(_, result, _)
			M.notes = vim.json.decode(result)
			if on_finish ~= nil then
				on_finish(M.notes)
			end
		end
	})
	if sync then
		job:sync()
	else
		job:start()
	end
end

local function calc_date(date, value, unit)
	if unit == "d" then
		unit = "days"
	elseif unit == "w" then
		unit = "weeks"
	end
	local result = ""
	---@diagnostic disable-next-line
	Job:new({
		command = 'date',
		args = { "-d", date .. " " .. value .. " " .. unit, "--iso-860" },
		on_stdout = function(_, output, _)
			result = output:sub(1, #output)
		end
	}):sync()
	return result
end

local function open_note(entry)
	local exist = entry[2] ~= vim.NIL
	if not exist then
		local name = os.date("%Y%m%d%H%M%S-") .. entry[1]:lower():gsub("'", "")
		local special_chars = { "<", ">", ":", "\"", "/", "\\", "|", "?", "*", " " }
		for _, value in ipairs(special_chars) do
			name = name:gsub(value, "_")
		end
		---@diagnostic disable-next-line
		entry[2] = Path.new(M.path, name).filename .. ".md"
	end
	vim.cmd.edit(entry[2])
	if not exist then
		local metadata = "---\ntitle: " .. entry[1] .. "\n---\n"
		vim.api.nvim_paste(metadata, false, -1)
	end
end

---@param line string
---@return table<string, string?>
local function get_schedule(line)
	local date, time, recurrence
	if not date then
		date, time, recurrence = line:match("scheduled:<(%d%d%d%d%-%d%d%-%d%d) (%d%d:%d%d) ([^>]+)")
	end
	if not date then
		date, time = line:match("scheduled:<(%d%d%d%d%-%d%d%-%d%d) (%d%d:%d%d)>")
	end
	if not date then
		date, recurrence = line:match("scheduled:<(%d%d%d%d%-%d%d%-%d%d) ([^>]+)")
	end
	if not date then
		date = line:match("scheduled:<(%d%d%d%d%-%d%d%-%d%d)>")
	end
	return {
		date = date,
		time = time,
		recurrence = recurrence
	}
end

M.search = function(opts)
	opts = opts or {}

	M.update()

	local results = {}
	for key, value in pairs(M.notes) do
		table.insert(results, { key, value })
	end

	local function select(prompt_bufnr, use_current_line)
		use_current_line = use_current_line or false
		actions.close(prompt_bufnr)

		local selected_entry
		if not use_current_line then
			selected_entry = action_state.get_selected_entry()
		end

		local entry
		if not selected_entry then
			entry = { action_state.get_current_line(), vim.NIL }
		else
			entry = selected_entry.value
		end

		open_note(entry)
	end

	local function create(prompt_bufnr)
		select(prompt_bufnr, true)
	end

	pickers.new(opts, {
		prompt_title = "Find or create a note...",
		finder = finders.new_table {
			results = results,
			entry_maker = function(entry)
				return {
					value = entry,
					display = (entry[2] == vim.NIL and " " .. entry[1]) or (" " .. entry[1]),
					ordinal = entry[1],
				}
			end
		},
		sorter = conf.generic_sorter(opts),
		previewer = previewers.new_buffer_previewer({
			define_preview = function(self, entry)
				entry = entry.value
				if entry[2] ~= vim.NIL then
					---@diagnostic disable-next-line
					local lines = vim.fn.readfile(Path.new(M.path, entry[2]).filename)
					vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
					vim.api.nvim_set_option_value('filetype', 'markdown', { buf = self.state.bufnr })
				end
			end
		}),
		attach_mappings = function(_, map)
			map("i", "<C-y>", create)
			actions.select_default:replace(select)
			return true
		end,
	}):find()
end

M.open_link = function()
	local line = vim.api.nvim_get_current_line()
	local row = vim.api.nvim_win_get_cursor(0)[2] + 1

	local reverse_line = line:sub(1, row):reverse()
	local reverse = reverse_line:find("[[", 1, true)

	-- If there is no [[ in front of the cursor, it means there is no link.
	if not reverse then
		return
	end

	local start_of_link = #reverse_line - reverse
	local end_of_link = start_of_link + line:sub(start_of_link, #line):find("]]", 1, true)

	-- If there is no ]] after [[, it means there is no link.
	if not end_of_link then
		return
	end

	local link = line:sub(start_of_link + 2, end_of_link - 2)
	M.update()
	for key, value in pairs(M.notes) do
		if key == link then
			open_note({ key, value })
			return
		end
	end
	open_note({ link, vim.NIL })
end

M.do_task = function()
	local line = vim.api.nvim_get_current_line()

	local is_done = false

	-- It's task?
	if not line:find("- [ ]", 1, true) then
		if line:find("- [x]", 1, true) then
			is_done = true
		else
			return
		end
	end

	local schedule = get_schedule(line)

	-- If task does not have recurrence, then just done or undone it
	if not schedule.recurrence and not is_done then
		line = line:gsub("- %[ %]", "- [x]")
	elseif not schedule.recurrence and is_done then
		line = line:gsub("- %[x%]", "- [ ]")
	end
	if schedule.recurrence then
		-- Unit is always the last character in "recurrence"
		local unit = schedule.recurrence:sub(#schedule.recurrence, #schedule.recurrence)
		local current_date = os.date("%Y-%m-%d")

		-- ++ is when we add the recurrence value until the new date is greater than today.
		-- .+ is when we ignore the task's scheduled date and just add the recurrence value.
		-- + is when we add the recurrence value to the scheduled date of the task.
		if schedule.recurrence:sub(1, 2) == "++" then
			local value = tonumber(schedule.recurrence:sub(3, #schedule.recurrence - 1))
			while schedule.date <= current_date do
				schedule.date = calc_date(schedule.date, value, unit)
			end
		elseif schedule.recurrence:sub(1, 2) == ".+" then
			local value = tonumber(schedule.recurrence:sub(3, #schedule.recurrence - 1))
			schedule.date = calc_date(current_date, value, unit)
		elseif schedule.recurrence:sub(1, 1) == "+" then
			local value = tonumber(schedule.recurrence:sub(2, #schedule.recurrence - 1))
			schedule.date = calc_date(schedule.date, value, unit)
		end

		-- Replace old schedule with new one, check if there was time and keep it
		if schedule.time then
			line = line:gsub("scheduled:<.+>",
				"scheduled:<" .. schedule.date .. " " .. schedule.time .. " " .. schedule.recurrence .. ">")
		else
			line = line:gsub("scheduled:<.+>", "scheduled:<" .. schedule.date .. " " .. schedule.recurrence .. ">")
		end
	end
	vim.api.nvim_set_current_line(line)
end

M.sort_task = function()
	local current_buffer = vim.api.nvim_get_current_buf()
	local start_line = vim.api.nvim_buf_get_mark(current_buffer, "<")[1] - 1
	local end_line = vim.api.nvim_buf_get_mark(current_buffer, ">")[1]
	local lines = vim.api.nvim_buf_get_lines(current_buffer, start_line, end_line, true)
	for i = #lines, 1, -1 do
		if lines[i] == "" then
			table.remove(lines, i)
		end
	end
	table.sort(lines, function(a, b)
		local a_scheduled = get_schedule(a)
		local b_scheduled = get_schedule(b)
		if a_scheduled.date == nil and b_scheduled.date == nil then
			return a < b
		elseif a_scheduled.date == nil and b_scheduled.date ~= nil then
			return false
		elseif b_scheduled.date == nil and a_scheduled.date ~= nil then
			return true
		end
		local a_scheduled_string = a_scheduled.date .. (a_scheduled.time or "23:59")
		local b_scheduled_string = b_scheduled.date .. (b_scheduled.time or "23:59")
		return a_scheduled_string < b_scheduled_string
	end)
	vim.api.nvim_buf_set_lines(current_buffer, start_line, end_line, true, lines)
end

return M
