#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <xmlrpc-c/base.h>
#include <xmlrpc-c/server.h>
#include <xmlrpc-c/server_cgi.h>
#include "oraccnet.h"

const char *varoracc = "/Users/stinney/varoracc";

static xmlrpc_value *ox_method(xmlrpc_env *const envP,
			       xmlrpc_value *const paramArrayP, 
			       void *serverInfo,
			       void *callInfo
			       );

struct xmlrpc_method_info3 ox_server_info =
{
  "ox",
  ox_method,
  NULL,
  0,
  "s:",
  "return the value of call_info structure with clientIP added to it from the environment",
};

static xmlrpc_value *
ox_method(xmlrpc_env *const envP,
	  xmlrpc_value *const paramArrayP, 
	  void *serverInfo,
	  void *callInfo
	  )
{
  const char *addr = getenv("REMOTE_ADDR");
  xmlrpc_value *s, *s_ret, *exec_ret;
  struct call_info *cip, *cip_clone;
  struct file_data *infile = NULL;

  trace();

  fprintf(stderr, "oracc-xmlrpc: ox: REMOTE_ADDR=%s\n", addr);
  xmlrpc_array_read_item(envP, paramArrayP, 0, &s);
  sesh_init(envP, s, 1);

  cip = callinfo_unpack(envP, s);
  cip->clientIP = addr;
  file_save(cip, "/Users/stinney/varoracc");

  trace();

  cip_clone = callinfo_clone(cip);
  cip_clone->files = NULL;
  cip_clone->methodargs = NULL;
  cip_clone = callinfo_clone(cip);

  s_ret = callinfo_pack(envP, cip_clone);
  
  infile = file_find(cip, "in");
  if (infile)
    {
      xmlrpc_value *b64;
      char *logfile = sesh_file("ox.log");
      trace();
      fprintf(stderr, "(1) argv[0] = %s\n", cip->methodargs[0]);
      callinfo_append_arg(cip, "l", NULL, logfile);
      callinfo_append_arg(cip, NULL, NULL, (const char *)infile->path);
      fprintf(stderr, "(2) argv[0] = %s\n", cip->methodargs[0]);
      exec_ret = request_exec(envP, "/usr/local/oracc/bin/ox", "ox", cip);
      b64 = file_b64(envP, logfile, "ox_log", "out");
      if (b64)
	{
	  fprintf(stderr, "adding %s to exec_ret\n", logfile);
	  xmlrpc_struct_set_value(envP, exec_ret, "ox_log", b64);
	}
    }
  else
    {
      trace();
      exec_ret = request_error(envP, "oracc-xmlrpc: ox: can't find input file (what=in). Stop", NULL);
    }
  
  xmlrpc_struct_set_value(envP, exec_ret, "callinfo", s_ret);
  trace();

  return exec_ret;
}