package modular.js;

import haxe.macro.Type.ClassField;
import modular.js.interfaces.IField;

using modular.js.StringExtender;


class Field extends Module implements IField {
    public var fieldAccessName:String;
    public var propertyAccessName:String;
    public var init: String;

    public function getCode() {
         return code;
    }

    public function build(f: ClassField, classPath:String) {
        name = f.name;
        path = '$classPath.$name';
        fieldAccessName = name.asJSFieldAccess(gen.api);
        propertyAccessName = name.asJSPropertyAccess(gen.api);
        var e = f.expr();
        if( e == null ) {
            code = 'null';
        } else {
            code = gen.api.generateValue(e);
        }
        for (dep in gen.getDependencies().keys()) {
            addDependency(dep);
        }
    }
}
