module Window
  def number
    (0..VIM::Window.count).each do |n|
      if Vim::Window[n] == self
        return n+1
      end
    end
  end
end

def current_window
  VIM::Window.current.extend Window
end

def switch_to_window w
  VIM::command "#{w.number}wincmd w"
end

def escape str
  str
    .gsub(/\\/, "\\\\")
    .gsub(/"/,  "\\\"")
end

def augroup group, &block
  VIM::command ":augroup #{group}"
  VIM::command ':autocmd!'
  block.call if block
  VIM::command ":augroup END"
end

def start_livemacro register
  source = current_window

  VIM::command ":below 1new --livemacro--"
  VIM::command ":setlocal buftype=nofile bufhidden=delete noswapfile nobuflisted noeol"
  VIM::command ":silent! put! #{register}"
  VIM::command ":$d"
  augroup "livemacro" do
    VIM::command ":autocmd CursorMoved,InsertLeave <buffer> :call UpdateLivemacro()"
    VIM::command ":autocmd BufWinLeave <buffer> :call CleanupLivemacro()"
  end

  lm_win = current_window
  lm_win.extend(Module.new do |m|
    define_method :source do source end
    define_method :register do register end
    attr_accessor :needs_undo
  end)
  lm_win.needs_undo = false
end

def update_livemacro
  lm_win = current_window

  old = VIM::evaluate("@#{lm_win.register}").chomp
  new = lm_win.buffer[1].chomp
  if old == new
    return
  end

  VIM::command ":let @#{lm_win.register} = \"#{escape new}\""
  switch_to_window lm_win.source
  if lm_win.needs_undo
    VIM::command ":undo"
  else
    lm_win.needs_undo = true
  end
  VIM::command ":normal! @#{lm_win.register}"

  switch_to_window lm_win
end

def cleanup_livemacro
  lm_win = current_window
  lm_win.needs_undo = false
  augroup "livemacro"
end