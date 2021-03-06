#
# Copyright 2016-2018, Intel Corporation
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in
#       the documentation and/or other materials provided with the
#       distribution.
#
#     * Neither the name of the copyright holder nor the names of its
#       contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#
# libpmempool_sync/TEST1.PS1 -- test for checking replica sync
#
[CmdletBinding(PositionalBinding=$false)]
Param(
    [alias("d")]
    $DIR = ""
    )

# standard unit test setup
. ..\unittest\unittest.ps1

require_test_type medium
require_fs_type any

setup

$LOG = "out${Env:UNITTEST_NUM}.log"
$LOG_TEMP = "out${Env:UNITTEST_NUM}_part.log"
rm $LOG -Force -ea si
touch $LOG
rm $LOG_TEMP -Force -ea si
touch $LOG_TEMP

$LAYOUT = "OBJ_LAYOUT${Env:SUFFIX}"
$POOLSET = "$DIR\pool0.set"

# Create poolset file
create_poolset $POOLSET `
    20M:$DIR\testfile1:x `
    20M:$DIR\testfile2:x `
    21M:$DIR\testfile3:x `
    R `
    40M:$DIR\testfile4:x `
    20M:$DIR\testfile5:x

# CLI script for writing some data hitting all the parts
$WRITE_SCRIPT = "$DIR\write_data"
echo @"
pr 55M
srcp 0 TestOK111
srcp 20M TestOK222
srcp 40M TestOK333
"@ | out-file -encoding ASCII -literalpath $WRITE_SCRIPT

# CLI script for reading 9 characters from all the parts
$READ_SCRIPT = "$DIR\read_data"
echo @"
srpr 0 9
srpr 20M 9
srpr 40M 9
"@ | out-file -encoding ASCII -literalpath $READ_SCRIPT

# Create a pool
expect_normal_exit $PMEMPOOL create --layout=$LAYOUT obj $POOLSET
cat -Encoding Ascii $LOG | out-file -append -encoding ascii -literalpath $LOG_TEMP

# Write some data into the pool, hitting three part files
expect_normal_exit $PMEMOBJCLI -s $WRITE_SCRIPT $POOLSET | out-file -append -encoding ascii -literalpath $LOG_TEMP

# Check if correctly written
expect_normal_exit $PMEMOBJCLI -s $READ_SCRIPT $POOLSET | out-file -append -encoding ascii -literalpath $LOG_TEMP

# Delete the second part in the primary replica
rm $DIR\testfile2 -Force -ea si

# Synchronize replicas
$FLAGS = "0"
expect_normal_exit $Env:EXE_DIR\libpmempool_sync$Env:EXESUFFIX `
    $POOLSET $FLAGS
cat -Encoding Ascii $LOG | out-file -append -encoding ascii -literalpath $LOG_TEMP

# Check if correctly synchronized
expect_normal_exit $PMEMOBJCLI -s $READ_SCRIPT $POOLSET | out-file -append -encoding ascii -literalpath $LOG_TEMP

mv -Force $LOG_TEMP $LOG
check
pass
