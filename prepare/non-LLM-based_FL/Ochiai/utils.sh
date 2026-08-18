# Copied from reproduction of SBIR (https://github.com/LASER-UMASS/SBIR-ReplicationPackage)

#!/usr/bin/env bash
export MALLOC_ARENA_MAX=1 # Iceberg's requirement
export TZ='America/Los_Angeles' # some D4J's requires this specific TimeZone

export _JAVA_OPTIONS="-Xmx6144M -XX:MaxHeapSize=4096M"
export MAVEN_OPTS="-Xmx2048M"
export ANT_OPTS="-Xmx6144M -XX:MaxHeapSize=4096M"

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

# Speed up grep command
alias grep="LANG=C grep"

#
# Prints error message to the stdout and exit.
#
die() {
  echo "$@" >&2
  exit 1
}

#
# Returns the test classpath of a previously checkout D4J's project-bug.
#
_get_test_classpath() {
  local USAGE="Usage: ${FUNCNAME[0]} <checkout_dir>"
  if [ "$#" != 1 ]; then
    echo "$USAGE" >&2
    return 1
  fi

  local checkout_dir="$1"
  [ -d "$checkout_dir" ] || die "[ERROR] $checkout_dir does not exist!"

  cp=$(cd "$checkout_dir" > /dev/null 2>&1 && \
       $D4J_HOME/framework/bin/defects4j compile > /dev/null 2>&1 && \
       $D4J_HOME/framework/bin/defects4j export -p cp.test) || die "[ERROR] Get classpath has failed!"
  [ "$cp" != "" ] || die "[ERROR] test-classpath is empty!"
  echo "$cp"
  return 0
}

#
# Return full path of the target directory of source classes.
#
_get_src_classes_dir() {
  local USAGE="Usage: ${FUNCNAME[0]} <checkout_dir>"
  if [ "$#" != 1 ]; then
    echo "$USAGE" >&2
    return 1
  fi

  local checkout_dir="$1"
  [ -d "$checkout_dir" ] || die "[ERROR] $checkout_dir does not exist!"
  
  src_classes_dir=$(cd "$checkout_dir" > /dev/null 2>&1 && \
                     $D4J_HOME/framework/bin/defects4j compile > /dev/null 2>&1 && \
                     $D4J_HOME/framework/bin/defects4j export -p dir.bin.classes) || die "[ERROR] Get test classes dir has failed!"
  [ "$src_classes_dir" != "" ] || die "[ERROR] src-classes-dir is empty!"

  echo "$checkout_dir/$src_classes_dir" # Return full path
  return 0
}

#
# Return full path of the target directory of test classes.
#
_get_test_classes_dir() {
  local USAGE="Usage: ${FUNCNAME[0]} <pid> <bid> <checkout_dir>"
  if [ "$#" != 3 ]; then
    echo "$USAGE" >&2
    return 1
  fi

  local pid="$1"
  local bid="$2"
  local checkout_dir="$3"
  [ -d "$checkout_dir" ] || die "[ERROR] $checkout_dir does not exist!"

  test_classes_dir=$(cd "$checkout_dir" > /dev/null 2>&1 && \
                     $D4J_HOME/framework/bin/defects4j compile > /dev/null 2>&1 && \
                     $D4J_HOME/framework/bin/defects4j export -p dir.bin.tests)
  if [ $? -ne 0 ]; then
    if [ "$pid" == "Chart" ]; then
      test_classes_dir="build-tests"
    elif [ "$pid" == "Closure" ]; then
      test_classes_dir="build/test"
    elif [ "$pid" == "Lang" ]; then
      if [ "$bid" -ge "1" ] && [ "$bid" -le "20" ]; then
        test_classes_dir="target/tests"
      elif [ "$bid" -ge "21" ] && [ "$bid" -le "41" ]; then
        test_classes_dir="target/test-classes"
      elif [ "$bid" -ge "42" ] && [ "$bid" -le "65" ]; then
        test_classes_dir="target/tests"
      else
        die "[ERROR] Get test classes dir has failed!"
      fi
    elif [ "$pid" == "Math" ]; then
      test_classes_dir="target/test-classes"
    elif [ "$pid" == "Mockito" ]; then
      if [ "$bid" -ge "1" ] && [ "$bid" -le "11" ]; then
        test_classes_dir="build/classes/test"
      elif [ "$bid" -ge "12" ] && [ "$bid" -le "17" ]; then
        test_classes_dir="target/test-classes"
      elif [ "$bid" -ge "18" ] && [ "$bid" -le "21" ]; then
        test_classes_dir="build/classes/test"
      elif [ "$bid" -ge "22" ] && [ "$bid" -le "38" ]; then
        test_classes_dir="target/test-classes"
      else
        die "[ERROR] Get test classes dir has failed!"
      fi
    elif [ "$pid" == "Time" ]; then
      if [ "$bid" -ge "1" ] && [ "$bid" -le "11" ]; then
        test_classes_dir="target/test-classes"
      elif [ "$bid" -ge "12" ] && [ "$bid" -le "27" ]; then
        test_classes_dir="build/tests"
      else
        die "[ERROR] Get test classes dir has failed!"
      fi
    else
      die "[ERROR] Get test classes dir has failed!"
    fi
  fi
  [ "$test_classes_dir" != "" ] || die "[ERROR] test-classes-dir is empty!"
  [ -d "$checkout_dir/$test_classes_dir" ] || die "[ERROR] $checkout_dir/$test_classes_dir does not exist!"

  echo "$checkout_dir/$test_classes_dir" # Return full path
  return 0
}

#
# Collect the list of classes (and inner classes) that might be faulty.
#
_collect_list_of_likely_faulty_classes() {
  local USAGE="Usage: ${FUNCNAME[0]} <pid> <bid> <checkout_dir> <output_file>"
  if [ "$#" != 4 ]; then
    echo "$USAGE" >&2
    return 1
  fi

  [ "$D4J_HOME" != "" ] || die "[ERROR] D4J_HOME is not set!"
  [ -d "$D4J_HOME" ] || die "[ERROR] $D4J_HOME does not exist!"

  local pid="$1"
  local bid="$2"
  local checkout_dir="$3"
  [ -d "$checkout_dir" ] || die "[ERROR] $checkout_dir does not exist!"
  local output_file="$4"
  >"$output_file" || die "[ERROR] Cannot write to $output_file!"

  local loaded_classes_file="$D4J_HOME/framework/projects/$pid/loaded_classes/$bid.src"
  [ -s "$loaded_classes_file" ] || die "[ERROR] $loaded_classes_file does not exist or it is empty!"
  echo "[DEBUG] loaded_classes_file: $loaded_classes_file" >&2

  # "normal" classes
  local normal_classes=$(cat "$loaded_classes_file" | sed 's/$/:/' | sed ':a;N;$!ba;s/\n//g')
  [ "$normal_classes" != "" ] || die "[ERROR] List of classes is empty!"
  local inner_classes=$(cat "$loaded_classes_file" | sed 's/$/$*:/' | sed ':a;N;$!ba;s/\n//g')
  [ "$inner_classes" != "" ] || die "[ERROR] List of inner classes is empty!"

  echo "$normal_classes$inner_classes" > "$output_file"
  return 0
}