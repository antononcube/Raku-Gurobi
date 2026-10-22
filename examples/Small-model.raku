use Gurobi;

say "Initializing Gurobi Interface...";
my $solver = Gurobi::Solver.new;

say "Creating a toy model...";
my $model = $solver.create-model("Raku_Test_Model");

say "Running optimization...";
my $status = $solver.solve($model);

say "Gurobi completed with code: $status";
