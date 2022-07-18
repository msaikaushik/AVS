package CLGTextTools::SimMeasures::CosineCV;

#twdoc
#
# Sim measure class which implements the cosine similarity for Context Vectors.
#
# ---
# EM Jul 2022
# 
#/twdoc
#

use strict;
use warnings;
use Carp;
use Log::Log4perl;
use CLGTextTools::Logging qw/confessLog cluckLog/;
use CLGTextTools::Commons qw/readTextFileLines arrayToHash/;
use Math::Trig;

use Data::Dumper qw(Dumper);

our @ISA=qw/CLGTextTools::SimMeasures::Measure/;

# TODO: add funtionality for getting m x n matrice for cosine similarities and get min, max, medium and range from that.


#twdoc new($class, $params)
#
# see parent. Additional parameters:
#
#/twdoc
sub new {
    my ($class, $params) = @_;
    my $self = $class->SUPER::new($params, __PACKAGE__);
    bless($self, $class);
    return $self;
}

sub calculateSimilarity {
    $\ = "\n";

    my $cv1 = $_[0];
    my $cv2 = $_[1];
    my $nbTokens = ${$_[2]};

    my @contextVec1 = @$cv1;
    my @contextVec2 = @$cv2;

    my $convec1 = ${\@contextVec1[0]};
    my $convec2 = ${\@contextVec2[0]};

    my @a = @{$convec1};
    my @b = @{$convec2};

    # print Dumper \@a;
    # print Dumper \@b;

    # print($nbTokens);
    # print("cv1");
    # print Dumper \@contextVec1[0];
    # print("cv2");


    # x*y/|x|*|y|
    my $sumxy = 0;
    my $sumxx = 0;
    my $sumyy = 0;

    for my $i (0 .. $#a) {
        my $val1 = $a[$i] / $nbTokens;
        my $val2 = $b[$i] / $nbTokens;

        $sumxx += ($val1 * $val1);
        $sumyy += ($val2 * $val2);
        $sumxy += ($val1 * $val2);
    }

    my $similarity = 0;
    $similarity = $sumxy / sqrt($sumxx * $sumyy);
    # print($similarity);
    # my $radians = acos($similarity);

    # return rad2deg($radians);

    return $similarity;
}


#twdoc compute($self, $doc1, $doc2)
#
# see parent.
#
#/twdoc
sub compute {
    # print Dumper \@_;

    my ($self, $doc1, $doc2) = @_;
    my %document1 = %$doc1;
    my %document2 = %$doc2;


    #for nbTokens;
    # print(${$d1{"nbTokens"}});
    # print(${$doc1->{"nbTokens"}});
    # print(%{$doc1->{"hashTokenRanking"}});

    my $nbtokens1 = ${$document1{"nbWords"}};
    my %hashTokenRanking1 = %{$document1{"hashTokenRanking"}};
    my %hashRankningToken1 = %{$document1{"hashRankingToken"}};

    my $nbtokens2 = ${$document2{"nbWords"}};
    my %hashTokenRanking2 = %{$document2{"hashTokenRanking"}};
    my %hashRankningToken2 = %{$document2{"hashRankingToken"}};

    # TODO: create a 2d matrix of cosine similarities and compute min, max, etc from all the values. 
    my @cosineSimilarityMatrix1 = ();
    my @cosineSimilarityMatrix2 = ();

    my ($obs1, $obs2, @cv1, @cv2);

    foreach $obs1 (keys %document1) {
        if ($obs1 eq "nbWords" or $obs1 eq "hashTokenRanking" or $obs1 eq "hashRankingToken") {
            next;
        }
        @cv1 = $document1{$obs1};

        foreach $obs2 (keys %document1) {
            if ($obs2 eq "nbWords" or $obs2 eq "hashTokenRanking" or $obs2 eq "hashRankingToken") {
                next;
            }

            @cv2 = $document1{$obs2};
            
            my $obs1Rank = $hashTokenRanking1{$obs1};
            my $obs2Rank = $hashTokenRanking1{$obs2};

            $cosineSimilarityMatrix1[$obs1Rank][$obs2Rank] = calculateSimilarity(\@cv1, \@cv2, \$nbtokens1);
        }
    }

    print Dumper \@cosineSimilarityMatrix1;


    # while (($obs2, $cv2) = each %$doc2) {
    #     if ($obs2 eq "nbTokens" or $obs2 eq "hashTokenRanking" or $obs2 eq "hashRankingToken") {
    #         next;
    #     }


    # }

    return 0;
}




1;
