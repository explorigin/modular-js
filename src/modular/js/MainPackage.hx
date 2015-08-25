package modular.js;

using StringTools;

class MainPackage extends Package {
	public override function getCode() {
		var pre = new haxe.Template('// Package: ::packageName::
require([::dependencyNames::],
	    function (::dependencyVars::) {
');

		//  Collect the package's dependencies into one array
		var allDeps = new haxe.ds.StringMap();
		var depKeys = [for (k in dependencies.keys()) k];

		var data = {
			packageName: name,
			path: path,
			dependencyNames: [for (k in depKeys) gen.api.quoteString(k.replace('.', '/'))].join(', '),
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
