package modular.js;

import haxe.ds.StringMap;
import modular.js.interfaces.IPackage;
import modular.js.interfaces.IKlass;

using StringTools;
using modular.js.StringExtender;

class Package extends Module implements IPackage {
    public var isMain:Bool = false;
    public var members: StringMap<IKlass> = new StringMap();

    public function isEmpty():Bool {
        return [for (m in members) if (!m.isEmpty()) true].length == 0 && code.trim() == "";
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

        function formatMember(m: IKlass) {
            var name = m.name;
            var access = m.name.asJSPropertyAccess(gen.api);

            return '$access: $name';
        }

        var data = {
            members: [for (member in memberValues) formatMember(member)].join(',\n\t\t'),
            singleMember: ""
        };

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

        if (code.indexOf("$bind(") != -1) {
            gen.addDependency('bind_stub', this);
        }

        if (code.indexOf("$iterator(") != -1) {
            gen.addDependency('iterator_stub', this);
        }

        var depKeys = [for (k in dependencies.keys()) k];
        var preData = {
            packageName: name,
            dependencyNames: depKeys.map(getDependencyName).join(', '),
            dependencyVars: [for (k in depKeys) k.replace('.', '_').replace('/', '_')].join(', '),
        };
        code = pre.execute(preData) + code;

        return code;
    }

    function getDependencyName(dependency:String)
    {
        var depth = path.split('.').length - 1;
        var root = depth == 0 ? './' : StringTools.lpad('', '../', depth * 3);
        dependency = dependency.replace('.', '/');
        var name = root + dependency;
        return gen.api.quoteString(name);
    }
}
