# Thanks @tlienart

using Franklin

using Markdown

function hfun_doc(params)
    fname = join(params[1:max(1, length(params)-2)], " ")
    head = params[end-1]
    type = params[end]
    doc = eval(Meta.parse("using FileTrees; @doc FileTrees.$fname"))
    txt = Markdown.plain(doc)
    # possibly further processing here
    body = Franklin.fd2html(txt, internal=true)
    return """
      <div class="docstring">
          <h2 class="doc-header" id="$fname">
            <a href="#$fname">$head</a>
            <div class="doc-type">$type</div></h2>
          <div class="doc-content">$body</div>
      </div>
    """
end
