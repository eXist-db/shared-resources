xquery version "3.0";

module namespace site="http://exist-db.org/apps/site-utils";

import module namespace templates="http://exist-db.org/xquery/templates";

declare variable $site:NOT_FOUND := xs:QName("site:NOT_FOUND");

declare %templates:wrap function site:expand-links($node as node(), $model as map(*), $base as xs:string?) {
    let $processed := templates:process($node/node(), $model)
    for $node in $processed
    return
        site:expand-links($node, $base)
};

declare %private function site:expand-links($node as node(), $base as xs:string?) {
    if ($node instance of element()) then
        let $href := $node/@href
        return
            if ($href) then
                let $expanded :=
                    if (starts-with($href, "/")) then
                        concat(request:get-context-path(), $href)
                    else
                        try {
                            site:expand-link($href, $base)
                        } catch * {
                            request:get-context-path() || "/404.html"
                        }
                return
                    element { node-name($node) } {
                        attribute href { $expanded },
                        $node/@* except $href, $node/node()
                    }
            else
                element { node-name($node) } {
                    $node/@*, for $child in $node/node() return site:expand-links($child, $base)
                }
    else
        $node
};

declare %private function site:expand-link($href as xs:string, $base as xs:string?) {
    string-join(
        let $analyzed := analyze-string($href, "^\{([^\{\}]+)\}")
        for $component in $analyzed/*/*
        return
            typeswitch($component)
                case element(fn:match) return
                    let $arg := $component/fn:group/string()
                    let $name := if (contains($arg, "|")) then substring-before($arg, "|") else $arg
                    let $fallback := substring-after($arg, "|")
                    let $app := collection(concat(repo:get-root(), "/", $name))
                    return
                        if ($app) then
                            concat(request:get-context-path(), request:get-attribute("$exist:prefix"), "/", $name)
                        else if ($fallback) then
                            $base || $fallback
                        else
                            error($site:NOT_FOUND, "Not found", $name)
                default return
                    $component/text()
        , ""
    )
};