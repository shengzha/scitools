package sci_commands::barnyard_compare;

use sci_utils::general;
use Getopt::Std; %opt = ();
use Exporter "import";
@EXPORT = ("barnyard_compare");

sub barnyard_compare {

@ARGV = @_;
getopts("O:q:n:f:T:", \%opt);

$mapQ = 20;
# $minR = 1000;
$minR = 1;
$maxF = 0.1;
$in_threads = 1;

$die2 = "
scitools barnyard-compare [options] [sorted rmdup filtered bam file]

Generates a human vs mouse barnyard comparison file & stats.
Reference must have GRCh38_ or GRCm39_ at the start of chromosome names to indicate species.

Will exclude /_(M|Y|L|K|G|Un|Random|Alt)/ chroms

Options:
   -O   [STR]   Output prefix (default is bam file prefix)
   -q   [INT]   Mapping quality filter (def = $mapQ)
   -n   [INT]   Min number of reads to consider cell (def = $minR)
   -f   [FLT]   Max fraction of other species to be considered pure (def = $maxF)
   -T   [INT]   Threads for the bam file read-in. (def = $in_threads)

";

if (!defined $ARGV[0]) {die $die2};
if (!defined $opt{'O'}) {$opt{'O'} = $ARGV[0]; $opt{'O'} =~ s/\.bam$//};
if (defined $opt{'n'}) {$minR = $opt{'n'}};
if (defined $opt{'q'}) {$mapQ = $opt{'q'}};
if (defined $opt{'f'}) {$maxF = $opt{'f'}};
if (defined $opt{'T'}) {$in_threads = $opt{'T'}};

open IN, "$samtools view -@ $in_threads -q $mapQ $ARGV[0] |";
while ($l = <IN>) {
	chomp $l;
	@P = split(/\t/, $l);
	$barc = $P[0]; $barc =~ s/:.+$//;
	if (!defined $BARC_total{$barc}) {
		$BARC_total{$barc} = 0;
		$BARC_human{$barc} = 0;
		$BARC_mouse{$barc} = 0;
	}
	if ($P[2] !~ /_(M|Y|L|K|G|Un|un|random|alt|Random|Alt)/) {
		if ($P[2] =~ /^GRCh38_/) {
			$BARC_total{$barc}++;
			$BARC_human{$barc}++;
		} elsif ($P[2] =~ /^GRCm39_/) {
			$BARC_total{$barc}++;
			$BARC_mouse{$barc}++;
		}
	}
} close IN;

$pure_cells = 0;
$mix_cells = 0;
$total_cells = 0;
$human_cells = 0;
$mouse_cells = 0;

open OUT, ">$opt{'O'}.barnyard.q${mapQ}.txt";
foreach $barc (sort {$BARC_total{$b}<=>$BARC_total{$a}} keys %BARC_total) {
	if ($BARC_total{$barc} >= $minR) {
		$frac_h = sprintf("%.2f", $BARC_human{$barc}/$BARC_total{$barc});
		$total_cells++;
		if ($frac_h>=(1-$maxF)) {
			$pure_cells++;
			$human_cells++;
			$call = "Human";
		} elsif ($frac_h<=$maxF) {
			$pure_cells++;
			$mouse_cells++;
			$call = "Mouse";
		} else {
			$mix_cells++;
			$call = "Mixed";
		}
		print OUT "$barc\t$BARC_total{$barc}\t$BARC_human{$barc}\t$BARC_mouse{$barc}\t$frac_h\t$call\n"
	}
} close OUT;

# open OUT, ">$opt{'O'}.barnyard_stats.txt";
# $frac_mix = sprintf("%.2f", $mix_cells/$total_cells);
# $est_total_collision = $frac_mix*2;
# print OUT "Barnyard stats for $ARGV[0]
# Total cells with $minR reads: $total_cells
# Cells called as human: $human_cells
# Cells called as mouse: $mouse_cells
# Cells with > $maxF from other species: $mix_cells ($frac_mix)
# Estimated total collision (mix fraction * 2): $est_total_collision
# ";
# close OUT;

}
1;