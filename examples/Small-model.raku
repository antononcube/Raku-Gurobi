use Gurobi;

# Maximize x + y + 2 z, with x + 2y + 3z <= 4 and x + y >= 1.
my $solver = Gurobi::Solver.new;
my $model = $solver.create-model('small-model');
my @variables = (
    $model.add-var(:obj(1), :vtype('B'), :name<x>),
    $model.add-var(:obj(1), :vtype('B'), :name<y>),
    $model.add-var(:obj(2), :vtype('B'), :name<z>),
);
$model.add-constr([0, 1, 2], [1, 2, 3], :sense('<'), :rhs(4), :name<capacity>);
$model.add-constr([0, 1], [1, 1], :sense('>'), :rhs(1), :name<coverage>);
$model.maximize;
my $status = $model.optimize;
die "Optimization did not finish optimally (status $status)" unless $status == GRB-OPTIMAL;
say "Objective: {$model.objective-value}";
for @variables.kv -> $i, $index { say "{@<x y z>[$i]} = {$model.value($index)}" }
