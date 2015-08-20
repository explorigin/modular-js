package modular.js;

import haxe.macro.Type.EnumType;
import haxe.macro.Type.EnumField;
import haxe.ds.StringMap;
import modular.js.interfaces.IKlass;
import modular.js.interfaces.IField;

using StringTools;
using modular.js.StringExtender;


class EnumModule extends Module implements IKlass {
    var names:String;
    var constructs:String;
    public var init = "";
    public var superClass:String;
    public var interfaces:Array<String> = [];
    public var members:StringMap<IField> = new StringMap();

    public function isEmpty() {
        return code == "" && !members.keys().hasNext() && init.trim() == "";
    }

    public function getCode() {
        var t = new haxe.Template('
// Enum: ::path::
::if (dependencies.length > 0)::
// Dependencies:
    ::foreach dependencies::
//  ::__current__::
    ::end::
::end::
var ::enumName:: = { __ename__ : [::names::], __constructs__ : [::constructs::] };
::if (code != "")::::enumName::.__meta__ = ::code::;::end::
::foreach members::
::enumName::::fieldAccessName:: = ::code::;
::end::
');
        function filterMember(member:IField) {
            var f = new EnumModuleField(gen);
            f.name = member.name;
            f.fieldAccessName = f.name.asJSFieldAccess(gen.api);
            f.code = member.getCode();
            return f;
        }

        var data = {
            enumName: name,
            code: code,
            path: path,
            dependencies: [for (key in dependencies.keys()) key],
            names: names,
            constructs: constructs,
            members: [for (member in members.iterator()) filterMember(member)]
        };

        return t.execute(data);
    }

    public function addField(e: EnumType, construct: EnumField) {
        gen.checkFieldName(e, construct);
        gen.setContext(path + '.' + e.name);
        var field = new EnumModuleField(gen);
        field.build(construct, path);

        members.set(construct.name, field);
    }

    public function build(e: EnumType) {
        name = e.name;
        path = gen.getPath(e);
        gen.setContext(path);

        names = path.split(".").map(gen.api.quoteString).join(",");
        constructs = e.names.map(gen.api.quoteString).join(",");

        for( c in e.constructs.keys() ) {
            addField(e, e.constructs.get(c));
        }
        var meta = gen.api.buildMetaData(e);
        if( meta != null ) {
            code = gen.api.generateStatement(meta);
        }
    }
}
