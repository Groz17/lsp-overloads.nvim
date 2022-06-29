local sig_popup = require("lsp-signature-enhanced.ui.signature_popup")
local settings = require("lsp-signature-enhanced.settings")
local util = require('vim.lsp.util')

local M = {}

local modify_sig = function(opts)
  -- Editing buffers is not allowed from <expr> mappings. The popup mappings are
  -- all <expr> mappings so they can be used consistently across modes, so instead
  -- of running the functions directly, they are run in an immediately executed
  -- timer callback.
  vim.fn.timer_start(0, function()
    opts.last_sig.activeSignature = opts.last_sig.activeSignature + (opts.sig_modifier or 0)
    opts.last_sig.activeParameter = opts.last_sig.activeParameter + (opts.param_modifier or 0)
    M.signature_handler(opts.last_sig.err, opts.last_sig, opts.last_sig.ctx,
      opts.last_sig.config)
  end)
end

---@param line_to_cursor string Text of the line up to the current cursor
---@param triggers list List of the trigger chars for firing a textDocument/signatureHelp request
local check_trigger_char = function(line_to_cursor, triggers)
  if not triggers then
    return false
  end

  for _, trigger_char in ipairs(triggers) do
    local current_char = line_to_cursor:sub(#line_to_cursor, #line_to_cursor)
    local prev_char = line_to_cursor:sub(#line_to_cursor - 1, #line_to_cursor - 1)
    if current_char == trigger_char then
      return true
    end
    if current_char == ' ' and prev_char == trigger_char then
      return true
    end
  end
  return false
end

local last_signature = {}

M.signature_handler = function(err, result, ctx, config)
  if result == nil then
    return
  end

  config = config or {}
  config.focus_id = ctx.method

  -- Clear the signature state and start from scratch based on the current
  -- line_to_cursor value
  last_signature = {}

  -- Store the new result in state so we can move between overloads and params
  last_signature = result
  last_signature.err = err
  last_signature.mode = vim.fn.mode()
  last_signature.ctx = ctx
  last_signature.config = config

  -- When use `autocmd CompleteDone <silent><buffer> lua vim.lsp.buf.signature_help()` to call signatureHelp handler
  -- If the completion item doesn't have signatures It will make noise. Change to use `print` that can use `<silent>` to ignore
  if not (result and result.signatures and result.signatures[1]) then
    if config.silent ~= true then
      print('No signature help available')
    end
    return
  end
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  local triggers = vim.tbl_get(client.server_capabilities, 'signatureHelpProvider', 'triggerCharacters')
  local ft = vim.api.nvim_buf_get_option(ctx.bufnr, 'filetype')

  local lines, hl = sig_popup.convert_signature_help_to_markdown_lines(result, ft, triggers)
  lines = vim.lsp.util.trim_empty_lines(lines)
  if vim.tbl_isempty(lines) then
    if config.silent ~= true then
      print('No signature help available')
    end
    return
  end

  local fbuf, fwin = vim.lsp.util.open_floating_preview(lines, 'markdown', config)
  local bufnr = vim.nvim_get_current_buf()

  local augroup = 'lsp_enhanced_sig_popup_' .. fwin
  vim.cmd(string.format([[
    augroup %s
      autocmd!
      autocmd WinLeave * if %d == <amatch> lua require("lsp-signature-enhanced.ui.signature_popup").remove_mappings(%d) endif
    augroup end
  ]], augroup, fwin, vim.api.nvim_get_current_buf()))

  if hl then
    vim.api.nvim_buf_add_highlight(fbuf, -1, 'LspSignatureActiveParameter', 0, unpack(hl))
  end


  sig_popup.add_mapping(bufnr, last_signature.mode, 'sig_next', settings.ui.keymaps.next_signature, modify_sig, { sig_modifier = 1, param_modifier = 0 })
  sig_popup.add_mapping(bufnr, last_signature.mode, 'sig_prev', settings.ui.keymaps.previous_signature, modify_sig, { sig_modifier = -1, param_modifier = 0 })
  sig_popup.add_mapping(bufnr, last_signature.mode, 'param_next', settings.ui.keymaps.next_parameter, modify_sig, { sig_modifier = 0, param_modifier = 1 })
  sig_popup.add_mapping(last_signature.mode, 'param_prev', settings.ui.keymaps.previous_parameter, modify_sig, { sig_modifier = 0, param_modifier = -1 })
end

local modify_sig = function(opts)
  -- Editing buffers is not allowed from <expr> mappings. The popup mappings are
  -- all <expr> mappings so they can be used consistently across modes, so instead
  -- of running the functions directly, they are run in an immediately executed
  -- timer callback.
  vim.fn.timer_start(0, function()
    opts.last_sig.activeSignature = opts.last_sig.activeSignature + (opts.sig_modifier or 0)
    opts.last_sig.activeParameter = opts.last_sig.activeParameter + (opts.param_modifier or 0)
    M.signature_handler(opts.last_sig.err, opts.last_sig, opts.last_sig.ctx,
      opts.last_sig.config)
  end)
end

return fbuf, fwin



  for _, client in pairs(clients) do
    local triggers = client.server_capabilities.signatureHelpProvider.triggerCharacters

    -- csharp has wrong trigger chars for some odd reason
    if client.name == 'csharp' then
      triggers = { '(', ',' }
    end

    local pos = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_get_current_line()
    local line_to_cursor = line:sub(1, pos[2])

    if not triggered then
      triggered = check_trigger_char(line_to_cursor, triggers)
    end
  end

  if triggered then
    local params = util.make_position_params()
    vim.lsp.buf_request(
      0,
      'textDocument/signatureHelp',
      params,
      vim.lsp.with(M.signature_handler, {
        border = 'single',
        silent = true,
        focusable = false,
      }))
  end
end

return M
