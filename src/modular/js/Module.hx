package modular.js;

import haxe.ds.StringMap;

import modular.js.JsGenerator;

using modular.js.StringExtender;


class Module {
    public var name:String = "";
    public var path:String = "";
    public var dependencies: StringMap<String> = new StringMap<String>();
    public var code: String = "";
    public var isStatic:Bool = false;
    public var globalInit:Bool = false;

    public var gen:JsGenerator;

    public function new(gen) {
        this.gen = gen;
    }

    function addDependency(dep:String) {
        gen.addDependency(dep, this);
    }

    inline function _print(b:StringBuf, str:String){
        b.add(str);
    }

    inline function _newline(b:StringBuf) {
        b.add(";\n");
    }

    function formatFieldName(name:String):String {
        return gen.api.isKeyword(name) ? '["' + name + '"]' : "." + name;
    }

    public var fieldName(get, never):String;

    function get_fieldName() {
        return name.asJSFieldAccess(gen.api);
    }
}
