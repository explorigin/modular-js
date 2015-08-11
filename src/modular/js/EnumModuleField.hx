package modular.js;

import haxe.macro.Type.EnumField;
import modular.js.interfaces.IField;

using modular.js.StringExtender;

class EnumModuleField extends Module implements IField {
    var isFunction:Bool;
    public var init: String;
    var index:Int;
    var enumName:String;
    var argNames:String;
    public var fieldAccessName:String;

    public function getCode() {
        var t = new haxe.Template('function(::argNames::) {
    var $$x = [::quoteName::,::index::::if (isFunction)::,::argNames::::end::];
    $$x.__enum__ = ::enumName::;
    return $$x;
}::if (!isFunction)::()::end::');

        var enumNameElements = enumName.split('.');
        var data = {
            argNames: argNames,
            index: index,
            isFunction: isFunction,
            enumName: enumNameElements[enumNameElements.length - 1],
            quoteName: gen.api.quoteString(name)
        };

        return t.execute(data);
    }

    public function build(e: EnumField, classPath:String) {
        name = e.name;
        fieldAccessName = name.asJSFieldAccess(gen.api);
        enumName = classPath;
        path = '$classPath.$name';
        index = e.index;

        switch( e.type )
        {
            case TFun(args, _):
                argNames = args.map(function(a) return a.name).join(",");
                isFunction = true;
            default:
                isFunction = false;
                argNames = "";
        }
    }
}
