local M = {}

local function is_excluded(dirname)
	local exclude_pattern = vim.g.backlinks_exclude_pattern
	if exclude_pattern ~= nil then
		-- Check if the directory name matches the exclude pattern
		local match = string.match(dirname, exclude_pattern)
		return match ~= nil
	end
	return false
end

local function line_has_pattern(line_text, wiki_pattern, markdown_pattern)
	if string.find(line_text, wiki_pattern, 1, true) then
		return true
	end

	if string.match(line_text, markdown_pattern) then
		return true
	end

	return false
end

local function scan_file(scan_filename, search_filename_core)
	local link_pattern_wiki = "[[" .. search_filename_core .. "]]"
	local link_pattern_markdown = "%[[^]]+%]%(.*" .. search_filename_core .. ".*%)"

	local results = {}

	local lines = vim.fn.readfile(scan_filename)
	for line_number, current_line_text in ipairs(lines) do
		if line_has_pattern(current_line_text, link_pattern_wiki, link_pattern_markdown) then
			results[#results + 1] = {
				filename = scan_filename,
				lnum = line_number,
				col = 0,
				text = current_line_text,
			}
		end
	end

	return results
end

function M.get_backlinks(dirname)
	-- Get current filename
	local filename_original = vim.fn.expand("%:t")
	-- Trim filename's extension(some links without extension)
	local filename_core = string.gsub(filename_original, "%.%a+$", "")
	-- Lua use pattern instead of regex
	-- http://www.lua.org/manual/5.1/manual.html#5.4.1
	-- Escape magic characters to construct link_pattern correctly
	filename_core = string.gsub(filename_core, "([%.%+%-%*%?%[%]%^%$%(%)%%])", "%%%1")

	-- Search directory
	dirname = dirname or vim.g.backlinks_search_dir

	-- Files to be searched
	local files = vim.tbl_filter(function(name)
		return not is_excluded(name) and vim.fn.isdirectory(name) == 0 -- 0 is file, 1 is directory
	end, vim.fn.globpath(dirname, "**/*", true, true))

	local results = {}

	for _, current_file in ipairs(files) do
		local scan_results = scan_file(current_file, filename_core)

		for _, single_result in ipairs(scan_results) do
			table.insert(results, single_result)
		end
	end

	-- Empty results
	if #results == 0 then
		vim.notify("No backlinks found for " .. filename_core .. " in " .. dirname, vim.log.levels.INFO)
	else
		-- Set the location list
		vim.fn.setloclist(0, results)

		-- Open the location list window
		vim.cmd("lopen")
	end
end

return M
