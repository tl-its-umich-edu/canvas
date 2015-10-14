set +x

function help {
echo "This script tests the Canvas TL API which allows canvas requests using masquerading."
echo "Copy the AUTH.sh.template file to AUTH.sh and fill in the appropriate tokens."
echo "The CanvasTLAdmin ESB API will allow masquarding by default.  The direct Canvas account"
echo "must be for a user with masquerade permissions."
echo ""
echo "If the right credentials are added the same queries can be run through different"
echo "access channels. E.g. they can be run via direct canvas access or"
echo "via access through a ESB API. See script for an example."
echo "The results of queries through different channels should be the same except:"
echo "- A query for the user actually running the query may give different information"
echo "as ESB API supplies it's own account for making queries."
echo "- The accounts for the direct and ESB quries need to have the same permissions in Canvas."
}

### Set the token and prefix values for the different users.
source ./AUTH.sh

help

echo "++++++++++ testing canvas access $CHANNEL_NAME ++++++++++"

function run_tests {
    echo "############################# $CHANNEL_NAME ###################"
#    echo "+++ trying self $CHANNEL_NAME +++"
#    USER_ID=self
#    curl -s -H "Authorization: Bearer ${TOKEN}" $URL_PREFIX/users/${USER_ID}/profile
#    echo
#    echo "----------"

#    echo "+++ trying sis_login_id $CHANNEL_NAME +++"
#    USER_ID=sis_login_id:dlhaines
#    curl -s -H "Authorization: Bearer ${TOKEN}" $URL_PREFIX/users/${USER_ID}/profile
#    echo
#    echo "----------"

    echo "+++ trying masquerading $CHANNEL_NAME +++"
    USER_ID=sis_login_id:dlhaines
    curl -s -H "Authorization: Bearer ${TOKEN}" $URL_PREFIX/users/self/profile?as_user_id=sis_login_id:studenta
    echo 
    echo "----------"
}


#### setup canvas direct user.
CHANNEL_NAME="CANVAS DIRECT"
TOKEN=$CANVAS_TOKEN
URL_PREFIX=$CANVAS_PREFIX
## comment out the canvas direct tests by default.

#run_tests

#### setup the ESB CanvasTLAdmin user.

CHANNEL_NAME="CANVAS ESB"
TOKEN=$ESB_TOKEN
URL_PREFIX=$ESB_PREFIX

run_tests

#end
