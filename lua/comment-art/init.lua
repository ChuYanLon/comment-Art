local M = {}
M.config = {
  data_path = vim.fn.stdpath('data') .. '/lazy/comment-Art/lua/comment-art/data.txt',
  data_en_path = vim.fn.stdpath('data') .. '/lazy/comment-Art/lua/comment-art/data-en.txt',
  language = 'english',
  prompt = {
    title_en = 'Generate pattern note:',
    title="生成图案注释:",
  },
  rules = {
    ['c'] = { prefix = '/* ', suffix = '*/', line_prefix = '* ', lines = true },
    ['cpp'] = { prefix = '/* ', suffix = '*/', line_prefix = '* ', lines = true },
    ['javascript'] = { prefix = '/* ', suffix = '*/', line_prefix = '* ', lines = true },
    ['typescript'] = { prefix = '/* ', suffix = '*/', line_prefix = '* ', lines = true },
    ['css'] = { prefix = '/* ', suffix = '*/', line_prefix = '* ', lines = true },
    ['scss'] = { prefix = '/* ', suffix = '*/', line_prefix = '* ', lines = true },
    ['vue'] = { prefix = '/* ', suffix = '*/', line_prefix = '* ', lines = true },
    ['javascriptreact'] = { prefix = '/* ', suffix = '*/', line_prefix = '* ', lines = true },
    ['typescriptreact'] = { prefix = '/* ', suffix = '*/', line_prefix = '* ', lines = true },
    ['python'] = { prefix = "'''", suffix = "'''", line_prefix = '', lines = true },
    ['sh'] = { prefix = '###', suffix = '###', line_prefix = '# ', lines = true },
    ['zsh'] = { prefix = '###', suffix = '###', line_prefix = '# ', lines = true },
    ['lua'] = { prefix = '--[[ ', suffix = ']]--', line_prefix = '', lines = true },
    ['java'] = { prefix = '/* ', suffix = '*/', line_prefix = '* ', lines = true },
    ['rust'] = { prefix = '/* ', suffix = '*/', line_prefix = '* ', lines = true },
    ['go'] = { prefix = '/* ', suffix = '*/', line_prefix = '', lines = true },
    ['less'] = { prefix = '// ', suffix = '', line_prefix = '// ' },
    ['html'] = { prefix = '<!-- ', suffix = '-->', line_prefix = '* ', lines = true },
    ['markdown'] = { prefix = '<!-- ', suffix = '-->', line_prefix = '', lines = true },
  },
}

local function get_filetype()
  local ft = vim.bo.filetype
  return M.config.rules[ft] and ft or ft
end

local function convert_to_comment(content)
  local filetype = get_filetype()
  local config = M.config.rules[filetype]
  if not config then
    vim.notify(
      "No comment configuration found for filetype '" .. filetype .. "'.",
      vim.log.levels.ERROR
    )
    return
  end

  local lines = {}
  for line in content:gmatch('[^\n\r]*') do
    table.insert(lines, line)
  end

  local result = {}
  local non_empty_lines = 0

  if config.lines and #lines > 1 then
    table.insert(result, config.prefix)

    for _, line in ipairs(lines) do
      if #line > 0 then
        table.insert(result, config.line_prefix .. line)
        non_empty_lines = non_empty_lines + 1
      end
    end

    if config.suffix and non_empty_lines > 0 then
      table.insert(result, config.suffix)
    end
  else
    for _, line in ipairs(lines) do
      if #line > 0 then
        table.insert(result, config.line_prefix .. line)
      end
    end
  end

  return result
end

local function insert_content(lines)
  local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
  vim.api.nvim_buf_set_lines(0, current_line, current_line, false, lines)
end

local function load_patterns()
  local file
  if M.config.language ~= 'chinese' then
    file = io.open(M.config.data_en_path, 'r')
  else
    file = io.open(M.config.data_path, 'r')
  end
  if not file then
    print('Error: Could not open data file')
    return {}
  end

  local content = file:read('*a')
  file:close()

  local patterns = {}
  local pattern_start = false
  local label = nil
  local content_lines = {}

  for line in content:gmatch('[^\n\r]+') do
    local new_label
    if M.config.language ~= 'chinese' then
      new_label = line:match('^%[Image:.-$') or line:match('^%[Text:.-$')
    else
      new_label = line:match('^%[图:.-$') or line:match('^%[文本:.-$')
    end
    if new_label then
      if pattern_start then
        table.insert(patterns, {
          label = label,
          content = table.concat(content_lines, '\n'),
        })
        content_lines = {}
      end
      label = new_label
      pattern_start = true
    elseif pattern_start and #line > 0 then
      table.insert(content_lines, line)
    end
  end

  if pattern_start and #content_lines > 0 then
    table.insert(patterns, {
      label = label,
      content = table.concat(content_lines, '\n'),
    })
  end

  return patterns
end

local function show_picker()
  local patterns = load_patterns()
  local options = {}
  for _, pattern in ipairs(patterns) do
    table.insert(options, pattern.label)
  end

  if #options == 0 then
    print('No patterns found in data file.')
    return
  end
  local prompt_title = M.config.language == 'chinese' and M.config.prompt.title or M.config.prompt.title_en
  vim.ui.select(options, {
    prompt = prompt_title,
    format_item = function(item)
      return item
    end,
  }, function(choice)
    if not choice then
      return
    end

    for _, pattern in ipairs(patterns) do
      if pattern.label == choice then
        local formatted = convert_to_comment(pattern.content)
        if formatted then
          insert_content(formatted)
        end
        return
      end
    end
  end)
end

local function setup(opt)
  M.config = vim.tbl_deep_extend('force', M.config, opt or {})
  vim.api.nvim_create_user_command('CommentArt', function()
    show_picker()
  end, {})
end

return { setup = setup }
