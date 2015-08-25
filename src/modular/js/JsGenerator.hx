package modular.js;

#if macro

import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.*;
import haxe.ds.*;
import haxe.crypto.Base64;
import haxe.crypto.Md5;
import haxe.io.Path;
import haxe.io.Bytes;
import sys.FileSystem;

using Lambda;
using StringTools;

enum Forbidden {
	prototype;
	__proto__;
	constructor;
}

class JsGenerator
{
	public var api : JSGenApi;

	var packages = new StringMap<Package>();
	var forbidden = new StringMap<Bool>();
	var baseJSModules : haxe.ds.StringMap<Bool>;
	public var currentContext = new Array<String>();
	var dependencies: StringMap<String> = new StringMap();
	var assumedFeatures: StringMap<Bool> = new StringMap();

	var curBuf : StringBuf;
	var mainBuf = new StringBuf();
	var external = false;
	var externNames = new StringMap<Bool>();
	var typeFinder = ~/\/\* "([A-Za-z0-9._]+)" \*\//g;
	var resourceFinder = ~/Resource\.get(String|Bytes)\("([A-Za-z0-9\/._]+)"\)/g; // "
	var jsStubPath:String;
	var outputDir:String;

	public function new(api) {
		this.api = api;

		curBuf = mainBuf;

		api.setTypeAccessor(getType);

		for (cp in Context.getClassPath()) {
			var path = FileSystem.absolutePath(cp);
			var index = path.indexOf('modular-js');
			if (index != -1) {
				jsStubPath = path.substr(0, index) + 'modular-js/js';
				break;
			}
		}

		outputDir = Path.directory(FileSystem.absolutePath(api.outputFile));
	}

	public function addFeature(name:String):Bool {
		return api.addFeature(name);
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
		} else if (dep != container.path) {
			container.dependencies.set(name, name);
		}
		return name;
	}

	function getType( t : Type ) {
		var origName = switch(t)
		{
			case TInst(c, _):
				var name = getPath(c.get());
				if (c.get().isExtern) {
					externNames.set(name, true);
				}

				name;
			case TEnum(e, _):
				addFeature("has.enum");
				getPath(e.get());
			case TAbstract(c, _):
				var name = getPath(c.get());
				if (c.get().isExtern) {
					externNames.set(name, true);
				}
				if (c.get().meta.has(":coreType")) {
					return name;
				}
				name;
			default: throw "assert: " + t;
		};

		return getTypeFromPath(origName);
	}

	public function isJSExtern(name: String): Bool {
		return externNames.exists(name);
	}

	public function getTypeFromPath(origName: String) {
		if (isJSExtern(origName)) {
			return origName;
		} else {
			addDependency(origName);
			return '/* "$origName" */';
		}
	}

	function depend_on_file(path, ?pack) {
		if (pack != null) {
			addDependency(path, pack);
		}

		sys.io.File.saveContent(
			Path.join([outputDir, path + '.js']),
			sys.io.File.getContent(Path.join([jsStubPath, path + '.js'])));

	}

	function print(str=''){
		curBuf.add(str);
		curBuf.add('\n');
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

	function traverseClass( c : ClassType ) {
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

	function traverseEnum( e : EnumType ) {
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

	function traverseType(t: Type) {
		switch(t) {
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
		var emptyPackages = [for (k in packages.keys()) if (packages.get(k).isEmpty()) k];
		if (emptyPackages.length > 0) {
			Context.warning('' + emptyPackages + ' are all empty packages.', Context.currentPos());
			for (name in emptyPackages) {
				packages.remove(name);
			}
		}
	}

	function addResourceDependency(f:EReg):String {
		var m = f.matched(2);
		var encodedName = Md5.encode(m);
		var pack = packages.get(currentContext[0]);
		var memberName = m.substring(m.lastIndexOf('.') + 1);

		addDependency('_resources/$encodedName', pack);

		return m;
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
		resourceFinder.map(pack.code, addResourceDependency);

		for (klsKey in pack.members.keys() ) {
			var kls = pack.members.get(klsKey);

			currentContext = [pack.path, klsKey];
			for (field in kls.members.iterator()) {
				field.code = typeFinder.map(field.code, replaceType);
				resourceFinder.map(field.code, addResourceDependency);
			}
			kls.code = typeFinder.map(kls.code, replaceType);
			resourceFinder.map(kls.code, addResourceDependency);
			if (kls.init != null)
				kls.init = typeFinder.map(kls.init, replaceType);
				resourceFinder.map(kls.code, addResourceDependency);
			if (kls.superClass != null) {
				kls.superClass = typeFinder.map(kls.superClass, replaceType);
			}
			kls.interfaces = [for (iface in kls.interfaces) typeFinder.map(iface, replaceType)];
		}
	}

	public function generate() {
		// Parse types and build packages
		api.types.map(traverseType);

		// Run through each package, making sure that it has collected the dependencies of it's members.
		for (pack in packages) { pack.collectDependencies(); }

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
		}

		purgeEmptyPackages();

		// Replace type comments
		for( pack in packages.iterator() ) {
			replaceTypeComments(pack);
		}

		// Loop through the created packages.
		for( pack in packages ) {
			var filePath:String;

			if (pack != mainPack) {
				curBuf = new StringBuf();
				var filename = pack.name.replace('.', '/');
				filePath = Path.join([outputDir, filename]);
				FileSystem.createDirectory(Path.directory(filePath));
				filePath += '.js';
			} else {
				continue;
			}

			print(pack.getCode());

			// Put it all in a file.
			sys.io.File.saveContent(filePath, curBuf.toString());
		}

		curBuf = mainBuf;

		print("self['$hxClasses'] = {};");

		if (hasFeature('has.enum')) {
			depend_on_file('enum_stub', mainPack);
		}

		depend_on_file('iterator_stub');
		depend_on_file('bind_stub');
		depend_on_file('extend_stub');

		var code = mainPack.getCode();

		for( pack in packages ) {
			for (member in pack.members) {
				// Handle Resources separately
				if (member.name == "Resource") {
					continue;
				}

				if (member.init != "") {
					print('\n// Init code for ${member.name}');
					print(member.init);
					print();
				}
			}
		}

		print(code);
		sys.io.File.saveContent(FileSystem.absolutePath(api.outputFile), curBuf.toString());

		// Handle Resources
		var resources = Context.getResources();
		var resourceDir = Path.join([outputDir, '_resources']);
		if (resources.keys().hasNext()) {
			FileSystem.createDirectory(resourceDir);
		}
		for (name in resources.keys()) {
			var encodedName = Md5.encode(name);
			var data = Base64.encode(resources.get(name));
			sys.io.File.saveContent(
				Path.join([resourceDir, '$encodedName.js']),
				'define(["haxe/Resource"], function(Resource) {
	// Resource: $name
	var data = "$data";
	if (Resource.content == null) {
		Resource.content = [];
	}
	Resource.content.push({name:"$name", data:data});
	return data;
});');
		}
	}

	#if macro
	public static function use() {
		Compiler.setCustomJSGenerator(function(api) new JsGenerator(api).generate());
	}
	#end

}
#end
