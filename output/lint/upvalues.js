// WoW's Lua 5.1 limits: at most 60 upvalues in a function, 200 locals in one. Prints each file's worst function.
//   node output/lint/upvalues.js File.lua [More.lua ...]   (from the addon folder)
const fs = require("fs");
const luaparse = require("./node_modules/luaparse");
for (const file of process.argv.slice(2)) {
  const ast = luaparse.parse(fs.readFileSync(file, "utf8"), { scope: true, locations: true, luaVersion: "5.1" });
  let worst = { up: 0 }, worstLocals = { n: 0 };
  // scopes: a stack of { names: Set, fn } ; a function's upvalues: names used inside from an enclosing function's scope
  function walkFunction(node, outer) {
    const fn = { node, scopes: [new Set()], up: new Set(), outer, locals: 0 };
    for (const p of node.parameters || []) if (p.type === "Identifier") { fn.scopes[0].add(p.name); fn.locals++; }
    walkBlock(node.body, fn);
    if (fn.up.size > worst.up) worst = { up: fn.up.size, line: node.loc.start.line };
    if (fn.locals > worstLocals.n) worstLocals = { n: fn.locals, line: node.loc.start.line };
    return fn;
  }
  function declared(fn, name) { return fn.scopes.some((s) => s.has(name)); }
  function use(fn, name) {
    if (declared(fn, name)) return;
    // from an enclosing function: an upvalue here and in every function between
    let f = fn.outer, chain = [fn];
    while (f) {
      if (declared(f, name)) { for (const c of chain) c.up.add(name); return; }
      chain.push(f); f = f.outer;
    }
  }
  function declare(fn, name) { fn.scopes[fn.scopes.length - 1].add(name); fn.locals++; }
  function walkBlock(body, fn) { fn.scopes.push(new Set()); for (const st of body) walk(st, fn); fn.scopes.pop(); }
  function walk(n, fn) {
    if (!n || typeof n !== "object") return;
    if (Array.isArray(n)) { for (const x of n) walk(x, fn); return; }
    switch (n.type) {
      case "Identifier": use(fn, n.name); return;
      case "LocalStatement": walk(n.init, fn); for (const v of n.variables) declare(fn, v.name); return;
      case "FunctionDeclaration":
        if (n.isLocal && n.identifier) declare(fn, n.identifier.name);
        else if (n.identifier) walk(n.identifier, fn);
        walkFunction(n, fn); return;
      case "ForNumericStatement":
        walk(n.start, fn); walk(n.end, fn); walk(n.step, fn);
        fn.scopes.push(new Set([n.variable.name])); fn.locals++; walkBlock(n.body, fn); fn.scopes.pop(); return;
      case "ForGenericStatement":
        walk(n.iterators, fn); fn.scopes.push(new Set(n.variables.map((v) => v.name))); fn.locals += n.variables.length;
        walkBlock(n.body, fn); fn.scopes.pop(); return;
      case "DoStatement": case "WhileStatement": walk(n.condition, fn); walkBlock(n.body, fn); return;
      case "RepeatStatement": fn.scopes.push(new Set()); for (const st of n.body) walk(st, fn); walk(n.condition, fn); fn.scopes.pop(); return;
      case "IfStatement": for (const c of n.clauses) { walk(c.condition, fn); walkBlock(c.body, fn); } return;
      case "MemberExpression": walk(n.base, fn); return;
      case "TableKeyString": walk(n.value, fn); return;
      default:
        for (const k of Object.keys(n)) if (k !== "loc" && k !== "range" && k !== "type") walk(n[k], fn);
    }
  }
  const top = walkFunction({ parameters: [], body: ast.body, loc: { start: { line: 1 } } }, null);
  const ok = worst.up <= 60 && top.locals <= 200 && worstLocals.n <= 200;
  console.log(`${ok ? "ok  " : "OVER"} ${file}: most upvalues ${worst.up} (function at line ${worst.line}), top-level locals ${top.locals}`);
}
