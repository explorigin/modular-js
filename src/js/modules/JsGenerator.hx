package js.modules;

#if macro

import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.*;
import haxe.ds.*;

using Lambda;
using StringTools;

using js.modules.JsGenerator.StringExtender;

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

enum Forbidden {
	prototype;
	__proto__;
	constructor;
}

enum StdTypes {
	Int;
	Float;
	Bool;
	Class;
	Enum;
	Dynamic;
}

enum JSTypes {
	Array;
	String;
	Object;
	Date;
	XMLHttpRequest;
	Math;
}

interface IField {
	var name:String;
	var code:String;
	var path:String;
	var isStatic:Bool;
	var dependencies:StringMap<String>;
	public function getCode():String;
}

interface IKlass {
	var name:String;
	var init:String;
	var code:String;
	var superClass:String;
	var interfaces:Array<String>;
	var dependencies:StringMap<String>;
	public function getCode():String;
	var members: StringMap<IField>;
}

interface IPackage {
	var name:String;
	var code:String;
	var members: StringMap<IKlass>;
}

class Module {
	public var name:String = "";
	public var path:String = "";
	public var dependencies: StringMap<String> = new StringMap<String>();
	public var code: String = "";
	public var isStatic:Bool = false;

	public var gen:JsGenerator;

	public function new(_gen) {
		gen = _gen;
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
//	::__current__::
	::end::
::end::
::if (overrideBase)::::if (useHxClasses)::$$hxClasses["::path::"] = ::className::::end::
::else::var ::className:: = ::if (useHxClasses == true)::$$hxClasses["::path::"] = ::end::::code::;
::if (interfaces != "")::::className::.__interfaces__ = [::interfaces::];
::end::::if (superClass != null)::::className::.__super__ = ::superClass::;
::className::.prototype = $$extend(::superClass::.prototype, {
::else::::className::.prototype = {
::end::::if (propertyString != "")::	"__properties__": {::propertyString::},
::end::::foreach members::	::propertyAccessName::: ::code::,
::end::	__class__: ::className::
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


class EnumModule extends Module implements IKlass {
	var names:String;
	var constructs:String;
	public var init: String;
	public var superClass:String;
	public var interfaces:Array<String> = [];
	public var members:StringMap<IField> = new StringMap();

	public function getCode() {
		var t = new haxe.Template('
// Enum: ::path::
::if (dependencies.length > 0)::
// Dependencies:
	::foreach dependencies::
//	::__current__::
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


class Package extends Module implements IPackage {
	public var isMain:Bool = false;
	public var members: StringMap<IKlass> = new StringMap();

	public function isEmpty():Bool {
		return !members.keys().hasNext() && code == "";
	}

	public function collectDependencies() {
		function hasDependency(key) {
			return ! dependencies.exists(key);
		}

		for( member in members ) {
			for( dep in [for (key in member.dependencies.keys()) key] ) {
				gen.addDependency(dep, this);
				member.dependencies.remove(dep);
			}
		}
	}

	public function getCode() {
		var pre = new haxe.Template('// Package: ::packageName::
define([::dependencyNames::],
	   function (::dependencyVars::) {
');

		//  Collect the package's dependencies into one array
		var allDeps = new StringMap();
		var memberValues = [for (member in members.iterator()) member];
		var depKeys = [for (k in dependencies.keys()) k];

		function formatMember(m: IKlass) {
			var name = m.name;
			var access = m.name.asJSPropertyAccess(gen.api);

			return '$access: $name';
		}

		var data = {
			packageName: name.replace('.', '_'),
			path: path,
			dependencyNames: [for (k in depKeys) gen.api.quoteString(k.replace('.', '_'))].join(', '),
			dependencyVars: [for (k in depKeys) k.replace('.', '_')].join(', '),
			members: [for (member in memberValues) formatMember(member)].join(',\n\t\t'),
			singleMember: ""
		};
		code = pre.execute(data);

		for (member in members) {
			code += member.getCode().indent(1);
		}

		var post:haxe.Template;

		if (memberValues.length == 1) {
			data.singleMember = memberValues[0].name;
			post = new haxe.Template('return ::singleMember::;
});
');
		} else {
			post = new haxe.Template('return {
		::members::
	};
});
');
		}

		code += post.execute(data);
		return code;
	}
}


class MainPackage extends Package {
	public override function getCode() {
		var pre = new haxe.Template('// Package: ::packageName::
require([::dependencyNames::],
	    function (::dependencyVars::) {
');

		//  Collect the package's dependencies into one array
		var allDeps = new StringMap();
		var depKeys = [for (k in dependencies.keys()) k];

		var data = {
			packageName: name.replace('.', '_'),
			path: path,
			dependencyNames: [for (k in depKeys) gen.api.quoteString(k.replace('.', '_'))].join(', '),
			dependencyVars: [for (k in depKeys) k.replace('.', '_')].join(', '),
		};
		var _code = pre.execute(data);

		_code += '\t$code';

		var post = new haxe.Template('
});
');
		_code += post.execute(data);
		return _code;
	}
}


class JsGenerator
{
	public var api : JSGenApi;

	var packages : StringMap<Package>;
	var forbidden : StringMap<Bool>;
	var baseJSModules : haxe.ds.StringMap<Bool>;
	public var currentContext: Array<String>;
	var dependencies: StringMap<String> = new StringMap();
	var assumedFeatures: StringMap<Bool> = new StringMap();

	var curBuf : StringBuf;
	var mainBuf : StringBuf;
	var external : Bool;
	public var hasClassInheritance: Bool = false;
	var typeFinder = ~/\/\* "([A-Za-z0-9._]+)" \*\//g;

	public function new(api)
	{
		this.api = api;
		mainBuf = new StringBuf();

		curBuf = mainBuf;
		currentContext = [];
		packages = new StringMap<Package>();
		forbidden = new StringMap();
		external = false;

		api.setTypeAccessor(getType);
	}

	public function hasFeature(name:String):Bool {
		var d = Context.definedValue(name);
		if (d != null) {
			return ["false", "no", ""].indexOf(d.toLowerCase()) == -1;
		}

		#if (haxe_ver >= 3.2)
		return api.hasFeature(name);
		#else
		if (!assumedFeatures.exists(name)) {
			Context.warning('Assuming feature "$name" is true until 3.2 is released.', Context.currentPos());
			assumedFeatures.set(name, true);
		}
		return true;
		#end

	}
	public function addDependency(dep:String, ?container:Module) {
		var name = dep;

		if (container == null) {
			dependencies.set(dep, name);
		} else if (! Reflect.hasField(JSTypes, dep)) {
			if (dep != container.path) {
				container.dependencies.set(name, name);
			} else {
			}
		} else {
			return "";
		}
		return name;
	}

	function getType( t : Type )
	{
		var origName = switch(t)
		{
			case TInst(c, _):
				getPath(c.get());
			case TEnum(e, _):
				getPath(e.get());
			case TAbstract(c, _):
				c.get().name;
			default: throw "assert: " + t;
		};

		return getTypeFromPath(origName);
	}

	public function getTypeFromPath(origName: String) {
		if (Reflect.hasField(StdTypes, origName)) {
			addDependency("Std");
		} else {
			addDependency(origName);
		}

		if (Reflect.hasField(JSTypes, origName)) {
			return origName;
		} else {
			return '/* "$origName" */';
		}
	}

	inline function print(str){
		curBuf.add(str);
	}

	public function getPath( t : BaseType ) {
		return (t.pack.length == 0) ? t.name : t.pack.join(".") + "." + t.name;
	}

	public function checkFieldName( c : {pos:Position}, f : {name:String} ) {
		if( forbidden.exists(f.name) )
			Context.error("The field " + f.name + " is not allowed in JS", c.pos);
	}

	public function setContext(ctxt:String) {
		currentContext = [ctxt];
		dependencies = new StringMap<String>();
	}

	public function getDependencies() {
		var depCopy = new StringMap<String>();
		for (key in dependencies.keys()) {
			depCopy.set(key, dependencies.get(key));
		}
		dependencies = new StringMap<String>();
		return depCopy;
	}

	function traverseClass( c : ClassType )
	{
		var pack = new Package(this);
		var kls = new Klass(this);
		api.setCurrentClass(c);
		kls.build(c);

		pack.path = getPath(c);
		pack.name = pack.path;
		if (pack.name == "") {
			pack.name = "core";
		}
		packages.set(pack.path, pack);
		pack.members.set(c.name, kls);
	}

	function traverseEnum( e : EnumType )
	{
		var kls = new EnumModule(this);
		kls.build(e);
		var pack = new Package(this);
		pack.path = getPath(e);
		pack.name = pack.path;
		if (pack.name == "") {
			pack.name = "core";
		}
		packages.set(pack.path, pack);
		pack.members.set(kls.name, kls);
	}

	function traverseType( t : Type )
	{
		switch( t )
		{
			case TInst(c, _):
				var c = c.get();
				if( !c.isExtern || ["Math", "Number"].indexOf(c.name) != -1) {
					traverseClass(c);
				} else {
					var path = getPath(c);
				}
			case TEnum(r, _):
				var e = r.get();
				if( !e.isExtern ) {
					traverseEnum(e);
				} else {
					var path = getPath(e);
				}
			// case TAbstract(a, _):
			// 	var name = a.get().name;
			// 	Context.warning('Skipping over Abstract: $name', Context.currentPos());
			// case TType(tt, _):
			// 	var name = tt.get().name;
			// 	Context.warning('Skipping over Type: $name', Context.currentPos());
			default:
				// Context.error('' + t, Context.currentPos());
		}
	}

	function purgeEmptyPackages() {
		// Dispose of Empty Packages
		var emptyPackages = [for (k in packages.keys()) k].filter(function(pName) { return packages.get(pName).isEmpty(); });
		if (emptyPackages.length > 0) {
			Context.warning('' + emptyPackages + ' are all empty packages.', Context.currentPos());
			for (name in emptyPackages) {
				packages.remove(name);
			}
		}
	}

	function cleanPackageDependencies(message="") {
		// Remove dependencies to non-existent packages
		var packageNames = [for (pack in packages) pack.path];
		for (pack in packages) {
			for (dep in pack.dependencies.keys()) {
				if (packageNames.indexOf(dep) == -1) {
					Context.warning('Removing dependency "$dep" from "${pack.name}".  $message', Context.currentPos());
					pack.dependencies.remove(dep);
				}
			}
		}
	}

	function checkForCyclicPackageDependencies():Array<String> {
		// Check packages for cyclic dependencies
		for( pack in packages.iterator() ) {
			var alreadyChecked = [pack.path];
			var depQueue = [for (dep in pack.dependencies.keys()) {path: dep, depPath: [pack.path]} ];

			while (depQueue.length > 0) {
				var dep = depQueue.shift();

				if (dep.path == pack.path) {
					Context.warning('${pack.name} is cyclically dependent along: ' + dep.depPath.join(' -> '), Context.currentPos());
					return dep.depPath;
				}

				if (alreadyChecked.indexOf(dep.path) != -1) {
					continue;
				}

				if (packages.exists(dep.path)) {
					var depPack = packages.get(dep.path);
					for (packDepKey in depPack.dependencies.keys()) {
						var queueStruct = {path: packDepKey, depPath: dep.depPath.concat([dep.path])}
						if (depQueue.indexOf(queueStruct) == -1) {
							depQueue.push(queueStruct);
						}
					}
				} else {
					Context.error('\tDepends on unknown module "$dep"', Context.currentPos());
				}
				alreadyChecked.push(dep.path);
			}
		}
		return [];
	}

	function joinPackages(a:Package, b:Package):Package {
		Context.warning('Joining packages ${a.path} and ${b.path}', Context.currentPos());
		for (member in a.members.keys()) {
			if (b.members.exists(member)) {
				Context.error('Cannot join packages ${a.path} and ${b.path} because they both have a member named $member.', Context.currentPos());
			}
			b.members.set(member, a.members.get(member));
		}
		b.code += '\n' + a.code;

		b.collectDependencies();
		return b;
	}

	function joinCyclicPackages() {
 		var cyclicPackages = [for (packName in checkForCyclicPackageDependencies()) packages.get(packName)];
		while(cyclicPackages.length != 0) {
			var finalPackage = cyclicPackages.slice(1).fold(joinPackages, cyclicPackages[0]);
			cyclicPackages = cyclicPackages.slice(1);
			for (pack in cyclicPackages) {
				packages.set(pack.path, finalPackage);
				finalPackage.dependencies.remove(pack.path);
			}
			cyclicPackages = [for (packName in checkForCyclicPackageDependencies()) packages.get(packName)];
		}
	}

	function replaceType(f:EReg):String {
		var m = f.matched(1);
		var pack = packages.get(currentContext[0]);
		var memberName = m.substring(m.lastIndexOf('.') + 1);

		if (pack.members.exists(m)) {
			return m;
		} else if (pack.dependencies.exists(m)) {
			var depPack = packages.get(m);

			if (!depPack.members.exists(memberName)) {
				Context.error('${pack.path} depends on $memberName from package ${depPack.path}, ${depPack.path} contains no member by that name.', Context.currentPos());
			}

			if (depPack.name != m) {
				// When packages are joined, the dependency name doesn't get updated so we do that here.
				pack.dependencies.set(depPack.name, pack.dependencies.get(m));
			}

			if (depPack.members.list().length == 1) {
				var depName = m.replace('.', '_');
				return depName;
			} else {
				var depName = depPack.name.replace('.', '_');
				return '$depName.$memberName';
			}
		} else if (pack.members.exists(memberName)) {
			return memberName;
		} else {
			// Context.warning('Assuming "$m" is available in "${pack.name}" scope.', Context.currentPos());
			return m;
		}
	}

	function replaceTypeComments(pack:Package) {
		currentContext = [pack.path];
		pack.code = typeFinder.map(pack.code, replaceType);

		for (klsKey in pack.members.keys() ) {
			var kls = pack.members.get(klsKey);

			currentContext = [pack.path, klsKey];
			for (field in kls.members.iterator()) {
				field.code = typeFinder.map(field.code, replaceType);
			}
			kls.code = typeFinder.map(kls.code, replaceType);
			if (kls.init != null)
				kls.init = typeFinder.map(kls.init, replaceType);
			if (kls.superClass != null) {
				kls.superClass = typeFinder.map(kls.superClass, replaceType);
			}
			kls.interfaces = [for (iface in kls.interfaces) typeFinder.map(iface, replaceType)];
		}
	}

	public function generate()
	{
		// Parse types and build packages
		api.types.map(traverseType);

		// Run through each package, making sure that it has collected the dependencies of it's members.
		for (pack in packages) { pack.collectDependencies(); }

		purgeEmptyPackages();
		cleanPackageDependencies("Assuming a global dependency.");
		joinCyclicPackages();

		// Special case, merge Math into Std
		if (packages.exists('Math') && packages.exists('Std')) {
			var stdPackage = joinPackages(packages.get('Math'), packages.get('Std'));
			packages.set('Math', stdPackage);
			packages.set('Std', stdPackage);
		}

		// Replace type comments
		for( pack in packages.iterator() ) {
			replaceTypeComments(pack);
		}

		var mainPack:MainPackage;
		if(api.main != null) {
			setContext("main");
			mainPack = new MainPackage(this);
			mainPack.name = 'main';
			mainPack.path = 'main';
			mainPack.code = api.generateStatement(api.main);
			for (dep in getDependencies().keys()) {
				addDependency(dep, mainPack);
			}
			packages.set('main', mainPack);
			replaceTypeComments(mainPack);
		}

		cleanPackageDependencies("It has been superceded by another dependency.");

		print("window.$hxClasses = {};");
		print('if (!window.require) alert("You must include an AMD loader such as RequireJS.");\n');

		// if (hasFeature("may_print_enum")) {
			print("$estr = function $estr() { return js.Boot.__string_rec(this, ''); };\n");
		// }

		// if (hasFeature("use.iterator")) {
			print("function $iterator(o) {
	if( o instanceof Array ) {
		return function() {
			return HxOverrides.iter(o);
		};
	}
	return typeof(o.iterator) == 'function' ? $bind(o,o.iterator) : o.iterator;
}\n");
		// }

		// if (hasFeature("use.bind")) {
			print("var $_, $fid = 0;
$bind = function $bind(o,m) {
	if( m == null ) { return null; }
	if( m.__id__ == null ) { m.__id__ = $fid++; }
	var f;
	if( o.hx__closures__ == null ) {
		o.hx__closures__ = {};
	} else {
		f = o.hx__closures__[m.__id__];
	}
	if( f == null ) {
		f = function(){
			return f.method.apply(f.scope, arguments);
		};
		f.scope = o;
		f.method = m;
		o.hx__closures__[m.__id__] = f;
	}
	return f;
}\n");
		// }

		if (hasClassInheritance) {
			print("$extend = function $extend(from, fields) {
	function Inherit() {};
	Inherit.prototype = from;
	var proto = new Inherit();
	for (var name in fields) proto[name] = fields[name];
	if(fields.toString !== Object.prototype.toString) proto.toString = fields.toString;
	return proto;
};\n");
		}

		// Loop through the created packages.
		for( pack in packages.iterator() ) {
			if (pack == mainPack)
				continue;

			curBuf = new StringBuf();
			var filename = pack.name.replace('.', '_');

			print(pack.getCode());
			// Put it all in a file.
			var filePath = api.outputFile.substring(0, api.outputFile.lastIndexOf("/"));
			filePath += '/$filename.js';
			sys.io.File.saveContent(filePath, curBuf.toString());
		}
		print("\n");

		curBuf = mainBuf;

		if( api.main != null ) {
			print(mainPack.getCode());
		}

		sys.io.File.saveContent(api.outputFile, mainBuf.toString());
	}

	#if macro
	public static function use()
	{
		Compiler.setCustomJSGenerator(function(api) new JsGenerator(api).generate());
	}
	#end

}
#end
