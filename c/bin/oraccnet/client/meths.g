%{
#include <string.h>
#include <xmlrpc-c/base.h>
#include "oraccnet.h"
extern struct client_method_info build_client_info;
extern struct client_method_info debug_client_info;
extern struct client_method_info deploy_client_info;
extern struct client_method_info environment_client_info;
extern struct client_method_info ox_client_info;
extern struct client_method_info status_client_info;
%}
struct meths_tab;
%%
build, &build_client_info
debug, &debug_client_info
deploy, &deploy_client_info
environment, &environment_client_info
ox, &ox_client_info
status, &status_client_info
