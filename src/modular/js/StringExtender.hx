package modular.js;

import haxe.macro.JSGenApi;

using StringTools;

class StringExtender {
    static public function asJSFieldAccess(s:String, api:JSGenApi) {
        return api.isKeyword(s) ? '["' + s + '"]' : "." + s;
    }
    static public function asJSPropertyAccess(s:String, api:JSGenApi) {
        return api.isKeyword(s) ? '"' + s + '"' : s;
    }
    static public function indent(s:String, level:Int) {
        var iStr = '';
        while (level > 0) {
            iStr += '\t';
            level -= 1;
        }
        return s.replace('\n', '\n$iStr');
    }
    static public function dedent(s:String, level:Int) {
        var iStr = '';
        while (level > 0) {
            iStr += '\t';
            level -= 1;
        }
        return s.replace('\n$iStr', '\n');
    }
}
