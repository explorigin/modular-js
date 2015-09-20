package modular.js.interfaces;

import haxe.ds.StringMap;

interface IKlass {
    var name:String;
    var init:String;
    var code:String;
    var superClass:String;
    var interfaces:Array<String>;
    var dependencies:StringMap<String>;
    public function getCode():String;
    public function isEmpty():Bool;
    var members: StringMap<IField>;
    var globalInit:Bool;
}
