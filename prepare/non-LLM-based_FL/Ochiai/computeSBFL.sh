# Adapted from reproduction of SBIR (https://github.com/LASER-UMASS/SBIR-ReplicationPackage)

CURRENT_PATH=$(readlink -f "$0")
CURRENT_DIR=$(dirname "$CURRENT_PATH")

TOOL_DIR=$(cd $CURRENT_DIR; cd ..; cd ..; pwd)/tools

RES_DIR=$CURRENT_DIR/res
REPO_DIR=$CURRENT_DIR/repos
SRC_DIR=$CURRENT_DIR

project=$1
bugid=$2

export D4J_HOME=$TOOL_DIR/defects4j-2.0.0
export GZOLTAR_CLI_JAR=$TOOL_DIR/gzoltar/gzoltar-1.7.2.201905090602/lib/gzoltarcli.jar 
export GZOLTAR_AGENT_JAR=$TOOL_DIR/gzoltar/gzoltar-1.7.2.201905090602/lib/gzoltaragent.jar 

source "$SRC_DIR/utils.sh" || exit 1
# Check whether D4J_HOME is set
[ "$D4J_HOME" != "" ] || die "[ERROR] D4J_HOME is not set!"
[ -d "$D4J_HOME" ] || die "[ERROR] $D4J_HOME does not exist!"

# Check whether GZOLTAR_CLI_JAR is set
[ "$GZOLTAR_CLI_JAR" != "" ] || die "GZOLTAR_CLI_JAR is not set!"
[ -s "$GZOLTAR_CLI_JAR" ] || die "$GZOLTAR_CLI_JAR does not exist or it is empty!"

# Check whether GZOLTAR_AGENT_JAR is set
[ "$GZOLTAR_AGENT_JAR" != "" ] || die "GZOLTAR_AGENT_JAR is not set!"
[ -s "$GZOLTAR_AGENT_JAR" ] || die "$GZOLTAR_AGENT_JAR does not exist or it is empty!"

# ------------------------------------------------------------------------- Main

echo "ProcessID: $$"
hostname
java -version

checkout_dir=$REPO_DIR/${project}-${bugid}
rm -rf "$checkout_dir"; mkdir -p "$checkout_dir"
"$D4J_HOME/framework/bin/defects4j" checkout -p "$project" -v "${bugid}b" -w "$checkout_dir"
echo "[DEBUG] checkout_dir: $checkout_dir" >&2

echo ""
echo "[INFO] Get Unit tests of ${project}_${bugid}b"

unit_tests_file="$checkout_dir/unit_tests.txt"
>"$unit_tests_file" || die "[ERROR] Cannot write to $unit_tests_file!"

test_classpath=$(_get_test_classpath "$checkout_dir")
echo "[DEBUG] test_classpath: $test_classpath" >&2

test_classes_dir=$(_get_test_classes_dir "$project" "$bugid" "$checkout_dir")
echo "[DEBUG] test_classes_dir: $test_classes_dir" >&2

src_classes_dir=$(_get_src_classes_dir "$checkout_dir")
# for Codec projects defects4j export doesnt give correct output
if [ "$project" == "Codec" ]; then
	src_classes_dir="$checkout_dir/target/classes"
fi
echo "[DEBUG] src_classes_dir: $src_classes_dir" >&2

all_tests_file="$checkout_dir/all_tests_file.txt"
($D4J_HOME/framework/bin/defects4j export -p tests.all -o "$all_tests_file" -w "$checkout_dir") || die "[ERROR] Failed to get all tests!"
[ -s "$all_tests_file" ] || die "[ERROR] $all_tests_file does not exist or it is empty!"
echo "[DEBUG] all_tests_file: $all_tests_file" >&2

# Some export commands might have removed some build files
(cd "$checkout_dir" > /dev/null 2>&1 && \
    $D4J_HOME/framework/bin/defects4j compile > /dev/null 2>&1) || die "[ERROR] Failed to compile the project!"

# Get unit tests
java -cp $D4J_HOME/framework/projects/lib/junit-4.11.jar:$test_classpath:$GZOLTAR_CLI_JAR \
    com.gzoltar.cli.Main listTestMethods \
    "$test_classes_dir" \
    --outputFile "$unit_tests_file" \
    --includes $(cat "$all_tests_file" | sed 's/$/#*/' | sed ':a;N;$!ba;s/\n/:/g') || die "GZoltar listTestMethods command has failed!"
[ -s "$unit_tests_file" ] || die "[ERROR] $output_file does not exist or it is empty!"

# for jacksondatabind projects, deleting test that triggers exception
# sed -i '/JUNIT,com.fasterxml.jackson.databind.misc.AccessFixTest#testCauseOfThrowableIgnoral/d' $unit_tests_file

classes_to_debug_file="$checkout_dir/classes_to_debug.txt"
>"$classes_to_debug_file" || die "[ERROR] Cannot write to $classes_to_debug_file!"
_collect_list_of_likely_faulty_classes "$project" "$bugid" "$checkout_dir" "$classes_to_debug_file"
classes_to_debug=$(cat "$classes_to_debug_file")

ser_file="$checkout_dir/gzoltar.ser"
# Some export commands might have removed some build files
(cd "$checkout_dir" > /dev/null 2>&1 && \
    $D4J_HOME/framework/bin/defects4j compile > /dev/null 2>&1) || die "[ERROR] Failed to compile the project!"

echo "[INFO] Start: $(date)" >&2
(cd "$checkout_dir" > /dev/null 2>&1 && \
     java -XX:MaxPermSize=2048M -javaagent:$GZOLTAR_AGENT_JAR=destfile=$ser_file,buildlocation=$src_classes_dir,includes=$classes_to_debug,excludes="",inclnolocationclasses=false,output="FILE" \
        -cp $src_classes_dir:$D4J_HOME/framework/projects/lib/junit-4.11.jar:$test_classpath:$GZOLTAR_CLI_JAR \
        com.gzoltar.cli.Main runTestMethods \
          --testMethods "$unit_tests_file" \
          --collectCoverage)
if [ $? -ne 0 ]; then
    echo "[ERROR] GZoltar runTestMethods command has failed for $project-${bugid}b version!" >&2
    return 1
fi
[ -s "$ser_file" ] || die "[ERROR] $ser_file does not exist or it is empty!"

DATA_DIR="$RES_DIR/${project}-$bugid"

mv "$ser_file" "$DATA_DIR/" || return 1
ser_file="$DATA_DIR/gzoltar.ser"
spectra_file="$DATA_DIR/sfl/txt/spectra.csv"
matrix_file="$DATA_DIR/sfl/txt/matrix.txt"
tests_file="$DATA_DIR/sfl/txt/tests.csv"

java -cp $src_classes_dir:$D4J_HOME/framework/projects/lib/junit-4.11.jar:$test_classpath:$GZOLTAR_CLI_JAR \
      com.gzoltar.cli.Main faultLocalizationReport \
        --buildLocation "$src_classes_dir" \
        --granularity "method" \
        --inclPublicMethods \
        --inclStaticConstructors \
        --inclDeprecatedMethods \
        --dataFile "$ser_file" \
        --outputDirectory "$DATA_DIR" \
        --family "sfl" \
        --formula "ochiai" \
        --metric "entropy" \
        --formatter "txt"
if [ $? -ne 0 ]; then
    echo "[ERROR] GZoltar faultLocalizationReport command has failed for $project-${bugid}b version!" >&2
    return 1
fi
echo "[INFO] End: $(date)" >&2

# ------------------------------------------------------------------------- Postprocess

[ -s "$spectra_file" ] || die "[ERROR] $spectra_file does not exist or it is empty!"
[ -s "$matrix_file" ] || die "[ERROR] $matrix_file does not exist or it is empty!"
[ -s "$tests_file" ] || die "[ERROR] $tests_file does not exist or it is empty!"
# Remove extension
mv "$spectra_file" $(dirname "$spectra_file")/$(basename "$spectra_file" .csv) || return 1
spectra_file=$(dirname "$spectra_file")/$(basename "$spectra_file" .csv)
mv "$matrix_file" $(dirname "$matrix_file")/$(basename "$matrix_file" .txt) || return 1
matrix_file=$(dirname "$matrix_file")/$(basename "$matrix_file" .txt)
mv "$tests_file" $(dirname "$tests_file")/$(basename "$tests_file" .csv) || return 1
tests_file=$(dirname "$tests_file")/$(basename "$tests_file" .csv)
# Remove header
tail -n +2 "$spectra_file" > "$spectra_file.tmp" && mv -f "$spectra_file.tmp" "$spectra_file" || return 1
tail -n +2 "$tests_file" > "$tests_file.tmp" && mv -f "$tests_file.tmp" "$tests_file" || return 1
# Backup
cp "$spectra_file" $(dirname "$spectra_file")/.spectra || return 1
# Remove inner class(es) names (as there is not a .java file for each one)
sed -i -E 's/(\$\w+)\$.*#/\1#/g' "$spectra_file" || return 1
# Remove method name of each row in the spectra file
sed -i 's/#.*:/#/g' "$spectra_file" || return 1
# Replace class name symbol
sed -i 's/\$/./g' "$spectra_file" || return 1

mv "$DATA_DIR/sfl/txt/matrix" "$DATA_DIR/matrix"
mv "$DATA_DIR/sfl/txt/ochiai.ranking.csv" "$DATA_DIR/ochiai.ranking.csv"
mv "$DATA_DIR/sfl/txt/tests" "$DATA_DIR/tests"
mv "$DATA_DIR/sfl/txt/.spectra" "$DATA_DIR/.spectra"
mv "$DATA_DIR/sfl/txt/spectra" "$DATA_DIR/spectra"
rm -rf "$DATA_DIR/sfl/"

# python3 $SRC_DIR/crush-matrix --formula ochiai --matrix $RES_DIR/${project}_$bugid/matrix --spectra $RES_DIR/${project}_$bugid/spectra --output $RES_DIR/${project}_$bugid/stmt-susps.txt