use v6.d;
use NativeCall;

unit module Gurobi;

# The gurobipy wheel does not install its library on the system linker path.
constant GRB-LIB = %*ENV<RAKU_GUROBI_LIB> // '/home/vscode/.local/lib/python3.14/site-packages/gurobipy/.libs/libgurobi130.so';
constant GRB-OPTIMAL is export = 2;
constant GRB-MAXIMIZE is export = -1;
constant GRB-MINIMIZE is export = 1;
constant GRB-INFINITY is export = 1e100;

my class GRBenv is repr('CPointer') { }
my class GRBmodel is repr('CPointer') { }
sub GRBloadenv(CArray[GRBenv], Str --> int32) is native(GRB-LIB) is symbol('GRBloadenv') { * }
sub GRBfreeenv(GRBenv) is native(GRB-LIB) is symbol('GRBfreeenv') { * }
sub GRBgeterrormsg(GRBenv --> Str) is native(GRB-LIB) is symbol('GRBgeterrormsg') { * }
sub GRBnewmodel(GRBenv, CArray[GRBmodel], Str, int32, CArray[num64], CArray[num64], CArray[num64], CArray[int8], CArray[Str] --> int32) is native(GRB-LIB) is symbol('GRBnewmodel') { * }
sub GRBfreemodel(GRBmodel) is native(GRB-LIB) is symbol('GRBfreemodel') { * }
sub GRBaddvar(GRBmodel, int32, CArray[int32], CArray[num64], num64, num64, num64, int8, Str --> int32) is native(GRB-LIB) is symbol('GRBaddvar') { * }
sub GRBaddconstr(GRBmodel, int32, CArray[int32], CArray[num64], int8, num64, Str --> int32) is native(GRB-LIB) is symbol('GRBaddconstr') { * }
sub GRBupdatemodel(GRBmodel --> int32) is native(GRB-LIB) is symbol('GRBupdatemodel') { * }
sub GRBoptimize(GRBmodel --> int32) is native(GRB-LIB) is symbol('GRBoptimize') { * }
sub GRBsetintattr(GRBmodel, Str, int32 --> int32) is native(GRB-LIB) is symbol('GRBsetintattr') { * }
sub GRBgetintattr(GRBmodel, Str, CArray[int32] --> int32) is native(GRB-LIB) is symbol('GRBgetintattr') { * }
sub GRBgetdblattr(GRBmodel, Str, CArray[num64] --> int32) is native(GRB-LIB) is symbol('GRBgetdblattr') { * }
sub GRBgetdblattrelement(GRBmodel, Str, int32, CArray[num64] --> int32) is native(GRB-LIB) is symbol('GRBgetdblattrelement') { * }

sub check(GRBenv $env, Int:D $code, Str:D $operation) { return if $code == 0; my $detail = $env.defined ?? GRBgeterrormsg($env) !! ''; die "Gurobi $operation failed (error $code)" ~ ($detail.chars ?? ": $detail" !! '') }
sub doubles(@values --> CArray[num64]) { my $r = CArray[num64].new; $r[$_] = @values[$_].Num for @values.keys; $r }
sub integers(@values --> CArray[int32]) { my $r = CArray[int32].new; $r[$_] = @values[$_].Int for @values.keys; $r }

class Gurobi::Model {
    has GRBenv $!env; has GRBmodel $!model; has Bool $!freed = False;
    has Int $!next-var = 0;
    submethod BUILD(:$env!, :$model!) { $!env = $env; $!model = $model }
    method add-var(Num :$obj = 0e0, Num :$lb = 0e0, Num :$ub = GRB-INFINITY, Str :$vtype = 'C', Str :$name = '' --> Int) {
        die 'Gurobi variable type must be a single character' unless $vtype.chars == 1;
        check($!env, GRBaddvar($!model, 0, Nil, Nil, $obj, $lb, $ub, $vtype.ord, $name), 'add-var');
        $!next-var++
    }
    method add-constr(@indices, @coefficients, Str :$sense = '<', Num :$rhs!, Str :$name = '') {
        die 'Constraint indices and coefficients must have the same length' unless @indices.elems == @coefficients.elems;
        die 'Constraint sense must be one of <, >, or =' unless $sense eq any('<', '>', '=');
        my $indices = integers(@indices); my $coefficients = doubles(@coefficients);
        check($!env, GRBaddconstr($!model, @indices.elems, $indices, $coefficients, $sense.ord, $rhs, $name), 'add-constr'); self
    }
    method maximize { check($!env, GRBsetintattr($!model, 'ModelSense', GRB-MAXIMIZE), 'set maximize'); self }
    method minimize { check($!env, GRBsetintattr($!model, 'ModelSense', GRB-MINIMIZE), 'set minimize'); self }
    method update { check($!env, GRBupdatemodel($!model), 'update model'); self }
    method optimize { self.update; check($!env, GRBoptimize($!model), 'optimize'); self.status }
    method status(--> Int) { my $v = CArray[int32].new; check($!env, GRBgetintattr($!model, 'Status', $v), 'get Status'); $v[0] }
    method num-vars(--> Int) { self.update; my $v = CArray[int32].new; check($!env, GRBgetintattr($!model, 'NumVars', $v), 'get NumVars'); $v[0] }
    method objective-value(--> Num) { my $v = CArray[num64].new; check($!env, GRBgetdblattr($!model, 'ObjVal', $v), 'get ObjVal'); $v[0] }
    method value(Int:D $index --> Num) { my $v = CArray[num64].new; check($!env, GRBgetdblattrelement($!model, 'X', $index, $v), 'get X'); $v[0] }
    method free { GRBfreemodel($!model) if !$!freed && $!model.defined; $!freed = True }
    method DESTROY { self.free }
}
class Gurobi::Solver {
    has GRBenv $!env; has Bool $!freed = False;
    submethod TWEAK() { my $p = CArray[GRBenv].new; my $code = GRBloadenv($p, ''); die "Gurobi environment initialization failed (error $code; verify the Gurobi license)" if $code != 0; $!env = $p[0] }
    method create-model(Str:D $name = 'model' --> Gurobi::Model) { die 'The Gurobi environment has been freed' if $!freed; my $p = CArray[GRBmodel].new; check($!env, GRBnewmodel($!env, $p, $name, 0, Nil, Nil, Nil, Nil, Nil), 'create model'); Gurobi::Model.new(:$!env, :model($p[0])) }
    method free { GRBfreeenv($!env) if !$!freed && $!env.defined; $!freed = True }
    method DESTROY { self.free }
}
