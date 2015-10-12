set +x

### Set the token and prefix values for the different users.
### Canvas token for a admin / masquerade canvas user.
CANVAS_PREFIX=https://umich.test.instructure.com/api/v1
ESB_PREFIX=https://api-qa-gw.its.umich.edu/CanvasTL/Admin/v1

## must contain values for CANVAS and ESB.
source ./AUTH.sh

echo "++++++++++ testing canvas access $TYPE ++++++++++"

function run_tests {
    echo "############################# $TYPE ###################"
    echo "+++ trying self $TYPE +++"
    USER_ID=self
    curl -s -H "Authorization: Bearer ${TOKEN}" $URL_PREFIX/users/${USER_ID}/profile
    echo "----------"

    echo "+++ trying sis_login_id $TYPE +++"
    USER_ID=sis_login_id:dlhaines
    curl -s -H "Authorization: Bearer ${TOKEN}" $URL_PREFIX/users/${USER_ID}/profile
    echo "----------"

    echo "+++ trying masquerading $TYPE +++"
    USER_ID=sis_login_id:dlhaines
    curl -s -H "Authorization: Bearer ${TOKEN}" $URL_PREFIX/users/self/profile?as_user_id=sis_login_id:studenta
    echo "----------"
}


#### setup canvas direct user.
TYPE="CANVAS DIRECT"
TOKEN=$CANVAS_TOKEN
URL_PREFIX=$CANVAS_PREFIX

run_tests

#### setup the ESB CanvasTLAdmin user.

TYPE="CANVAS ESB"
TOKEN=$ESB_TOKEN
URL_PREFIX=$ESB_PREFIX

run_tests

#end
