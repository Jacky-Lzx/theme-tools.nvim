"""Validate shared icons in real consumer windows through native terminal input."""

import json
import signal
import tempfile
from pathlib import Path

from tui import Terminal

signal.signal(
    signal.SIGALRM,
    lambda *_: (_ for _ in ()).throw(TimeoutError("Consumer icon TUI timed out")),
)
signal.alarm(50)
root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="/tmp/theme-icon-consumers-") as temporary:
    directory = Path(temporary)
    init = directory / "init.lua"
    init.write_text(f"""
vim.opt.rtp:prepend({json.dumps(str(root))})
for _,name in ipairs({{'selection','completion','ui','lsp','notification'}}) do
  vim.opt.rtp:append({json.dumps(str(root.parent))} .. '/' .. name .. '-tools.nvim')
end
vim.o.swapfile=false
vim.env.XDG_STATE_HOME={json.dumps(str(directory / "state"))}
vim.env.XDG_CACHE_HOME={json.dumps(str(directory / "cache"))}
warnings={{}}
vim.notify=function(message) warnings[#warnings+1]=message end
t=require('theme_tools'); i=t.icons
t.setup({{catppuccin=false,dracula=false,persist=false,themes={{'habamax'}},default='habamax',
  picker={{backend='selection_tools'}},icons={{default='ascii'}}}})
s=require('selection_tools')
s.setup({{keys={{next={{'<A-j>','<C-n>'}},previous={{'<A-k>','<C-p>'}}}}}})
c=require('completion_tools')
c.setup({{auto_show=false,sources={{'fixture'}},min_keyword_length=0,
  providers={{fixture={{complete=function(_,done)
    done({{items={{{{label='function_name',kind=3}},{{label='function_other',kind=3}}}}}})
  end}}}}}})
function visible_text(ft)
  local lines={{}}
  for _,win in ipairs(vim.api.nvim_list_wins()) do
    local buf=vim.api.nvim_win_get_buf(win)
    if not ft or vim.bo[buf].filetype==ft then
      vim.list_extend(lines,vim.api.nvim_buf_get_lines(buf,0,-1,false))
    end
  end
  return table.concat(lines,'\\n')
end
""")
    term = Terminal(init, directory / "nvim.sock")
    try:
        term.keys(b"i")
        term.lua("c.show()")
        assert term.lua(
            "return vim.wait(2000,function() return c.is_menu_visible() end)"
        )
        assert "F function_name" in term.lua("return visible_text()")
        term.keys(b"\x0e")
        selected = term.lua("return c.get_selected_item().label")
        term.lua("assert(i.set('none'))")
        assert term.lua("return c.get_selected_item().label") == selected
        assert "F function_name" not in term.lua("return visible_text()")
        term.lua("assert(i.set('ascii'))")
        assert "F function_name" in term.lua("return visible_text()")
        term.keys(b"\t!\x1b")
        assert term.lua("return vim.api.nvim_get_current_line()") == selected + "(!)"
        term.lua("c.dispose()")

        term.lua("""
          assert(i.set('ascii'))
          p=s.open({items={{file='/tmp/one.lua',text='one.lua'},{file='/tmp/two.lua',text='two.lua'}},
            format_item=function(item) return item.text end})
        """)
        term.keys(b"\x1bj")
        chosen = term.lua("return p:current().file")
        assert "f two.lua" in term.lua("return visible_text()")
        term.lua("assert(i.set('none'))")
        assert term.lua("return p:current().file") == chosen
        assert "f two.lua" not in term.lua("return visible_text()")
        term.keys(b"\x1bk\x1b")
        assert term.lua("return #vim.api.nvim_list_wins()") == 1

        term.lua("""
          assert(i.set('ascii'))
          dashboard=require('ui_tools.dashboard')
          dashboard.open({autostart=false,header='',footer='',keys={
            {key='f',desc='Search',icon='󰈔 ',action='enew'}}})
        """)
        assert "/ Search" in term.lua("return visible_text()")
        term.keys(b":ThemeToolsIcons\rnone\r")
        assert term.lua("return i.current()") == "none"
        assert "/ Search" not in term.lua("return visible_text()")
        assert "Search" in term.lua("return visible_text()")
        term.lua("dashboard.close(); assert(i.set('ascii'))")

        term.lua("""
          local api=vim.api
          source=api.nvim_get_current_win()
          api.nvim_buf_set_name(0,'/tmp/shared-icons.lua')
          api.nvim_buf_set_lines(0,0,-1,false,{'function Parent()',' local child=1','end'})
          local function range(a,b) return {start={line=a,character=0},['end']={line=b,character=0}} end
          local symbols={{name='Parent',kind=12,range=range(0,3),selectionRange=range(0,1),
            children={{name='child',kind=13,range=range(1,2),selectionRange=range(1,2)}}}}
          client={id=99,name='fixture',offset_encoding='utf-8'}
          function client:request(_,_,done) vim.schedule(function() done(nil,symbols) end); return true,1 end
          function client:cancel_request() end
          function client:stop() end
          vim.lsp.get_clients=function() return {client} end
          vim.lsp.get_client_by_id=function(id) return id==99 and client end
          vim.lsp.buf_is_attached=function() return true end
          outline=require('lsp-tools.outline')
          outline.setup({debounce=10,request_timeout=1000,mode='all'})
          outline.open()
          crumbs=require('lsp-tools.breadcrumbs')
          crumbs.setup({debounce=10,request_timeout=1000,winbar=true})
        """)
        assert term.lua(
            "return vim.wait(2000,function() return visible_text('lsp-tools-outline'):find('F Parent',1,true) end)"
        )
        term.lua("assert(i.set('none'))")
        assert "F Parent" not in term.lua("return visible_text('lsp-tools-outline')")
        assert "Parent" in term.lua("return visible_text('lsp-tools-outline')")
        term.lua(
            "outline.disable(); crumbs.disable(); vim.api.nvim_set_current_win(source)"
        )

        term.lua("""
          assert(i.set('ascii'))
          n=require('notification-tools')
          n.setup({notify=false,timeout=0,lsp={enabled=false},progress={stale_timeout=0,display_delay=0,done_ttl=10000}})
          n.notify('message','error',{title='Notice'})
          task=n.progress({title='Build'}); task:finish()
        """)
        assert term.lua(
            "return vim.wait(2000,function() local x=visible_text('notification-tools'); return x:find('E Notice',1,true) and x:find('+ Build',1,true) end)"
        )
        term.lua("assert(i.set('none'))")
        assert term.lua(
            "return vim.wait(2000,function() local x=visible_text('notification-tools'); return x:find('Notice',1,true) and not x:find('E Notice',1,true) and not x:find('+ Build',1,true) end)"
        )
        term.lua("n.teardown()")
        assert term.lua("return vim.api.nvim_get_current_line()") == "function Parent()"
        assert not term.lua("return visible_text():find('Error in',1,true)")
    except Exception:
        print(term.output[-3500:].decode(errors="replace"))
        raise
    finally:
        term.close()

print(
    "consumer PTY: live completion selection/acceptance, picker caches, Dashboard selector, outline and notification refresh passed"
)
