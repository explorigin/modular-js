package modular.js;

import haxe.macro.Type.ClassType;
import haxe.macro.Type.ClassField;
import haxe.ds.StringMap;
import modular.js.interfaces.IField;
import modular.js.interfaces.IKlass;

using StringTools;
using modular.js.StringExtender;


class Klass extends Module implements IKlass {
    public var members: StringMap<IField> = new StringMap();
    public var init: String;

    public var superClass:String = null;
    public var interfaces:Array<String> = new Array();
    public var properties:Array<String> = new Array();

    public function getCode() {
        var t = new haxe.Template('
// Class: ::path::
::if (dependencies.length > 0)::
// Dependencies:
    ::foreach dependencies::
//  ::__current__::
    ::end::
::end::
::if (overrideBase)::::if (useHxClasses)::$$hxClasses["::path::"] = ::className::::end::
::else::var ::className:: = ::if (useHxClasses == true)::$$hxClasses["::path::"] = ::end::::code::;
::if (interfaces != "")::::className::.__interfaces__ = [::interfaces::];
::end::::if (superClass != null)::::className::.__super__ = ::superClass::;
::className::.prototype = $$extend(::superClass::.prototype, {
::else::::className::.prototype = {
::end::::if (propertyString != "")::    "__properties__": {::propertyString::},
::end::::foreach members::  ::propertyAccessName::: ::code::,
::end:: __class__: ::className::
}::if (superClass != null)::)::end::;
::className::.__name__ = "::path::";::end::
::foreach statics::::className::::fieldAccessName:: = ::code::;
::end::::if (init != "")::// Initialization Code
::init::::end::
');
        function filterMember(member:IField) {
            var f = new Field(gen);
            f.name = member.name;
            f.fieldAccessName = f.name.asJSFieldAccess(gen.api);
            f.propertyAccessName = f.name.asJSPropertyAccess(gen.api);
            f.isStatic = member.isStatic;
            f.code = member.getCode();
            if (!f.isStatic) {
                f.code = f.code.indent(1);
            }
            return f;
        }

        var initCode = "";
        if (init != null) {
            initCode = init.trim().dedent(1);
        }

        var data = {
            overrideBase: Reflect.hasField(JSTypes, name),
            className: name,
            path: path,
            code: code,
            useHxClasses: gen.hasFeature('Type.resolveClass') || gen.hasFeature('Type.resolveEnum'),
            init: initCode,
            dependencies: [for (key in dependencies.keys()) key],
            interfaces: interfaces.join(','),
            superClass: superClass,
            propertyString: [for (prop in properties) '"$prop":"$prop"'].join(','),
            members: [for (member in members.iterator()) filterMember(member)].filter(function(m) { return !m.isStatic; }),
            statics: [for (member in members.iterator()) filterMember(member)].filter(function(m) { return m.isStatic; })
        };
        return t.execute(data);
    }

    public function addField(c: ClassType, f: ClassField) {
        gen.checkFieldName(c, f);
        gen.setContext(path + '.' + f.name);

        if(f.name.indexOf("get_") == 0 || f.name.indexOf("set_") == 0)
        {
            properties.push(f.name);
        }
        switch( f.kind )
        {
            case FVar(r, _):
                if( r == AccResolve ) return;
            default:
        }

        var field = new Field(gen);
        field.build(f, path);
        for (dep in field.dependencies.keys()) {
            addDependency(dep);
        }
        members.set(f.name, field);
    }

    public function addStaticField(c: ClassType, f: ClassField) {
        gen.checkFieldName(c, f);
        gen.setContext(path + '.' + f.name);
        var field = new Field(gen);
        field.build(f, path);
        field.isStatic = true;
        for (dep in field.dependencies.keys()) {
            addDependency(dep);
        }
        members.set(field.name, field);
    }

    public function build(c: ClassType) {
        name = c.name;
        path = gen.getPath(c);

        gen.setContext(path);
        if (c.init != null)
            init = gen.api.generateStatement(c.init);

        if( c.constructor != null ) {
            code = gen.api.generateStatement(c.constructor.get().expr());
        } else {
            code = "function() {}";
        }

        // Add Haxe type metadata
        if( c.interfaces.length > 0 ) {
            interfaces = [for (i in c.interfaces) gen.getTypeFromPath(gen.getPath(i.t.get()))];
        }
        if( c.superClass != null ) {
            gen.hasClassInheritance = true;
            superClass = gen.getTypeFromPath(gen.getPath(c.superClass.t.get()));
        }
        for (dep in gen.getDependencies().keys()) {
            addDependency(dep);
        }

        if (!c.isExtern) {
            for( f in c.fields.get() ) {
                addField(c, f);
            }

            for( f in c.statics.get() ) {
                addStaticField(c, f);
            }
        }
    }
}
