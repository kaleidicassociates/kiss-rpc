﻿module IDL.idl_parse;

import std.array;
import std.range.primitives : popFrontN;
import std.array : appender;
import std.regex;
import std.stdio;
import std.conv;
import std.file;
import std.format;
import std.process;

import IDL.IdlSymbol;
import IDL.IdlParseStruct;
import IDL.IdlParseInterface;
import IDL.IdlBaseInterface;
import IDL.IdlFlatbufferCreateCode;
import IDL.IdlUnit;


class idl_parse
{
	this()
	{
		//idlDlangVariable["void"] = "void";
		idlDlangVariable["bool"] = "bool";
		idlDlangVariable["byte"] = "byte";
		idlDlangVariable["ubyte"] = "ubyte";
		idlDlangVariable["short"] = "short";
		idlDlangVariable["ushort"] = "ushort";
		idlDlangVariable["int"] = "int";
		idlDlangVariable["uint"] = "uint";
		idlDlangVariable["long"] = "long";
		idlDlangVariable["ulong"] = "ulong";
		idlDlangVariable["float"] = "float";
		idlDlangVariable["double"] = "double";
		idlDlangVariable["char"] = "char";
		idlDlangVariable["string"] = "string";
	}

	void setParseFile(string path)
	{
		inFilePath = path;
	}

	void setOutputFile(string path)
	{
		outFilePath = path;
	}

	void setFileName(string name)
	{
		fileName = name;
	}

	void startParse()
	{
		auto file = File(inFilePath);
	
		string text;

		while(!file.eof)
		{
			text ~= file.readln();
		}

		this.parse(text);
	}

	bool parse(string data)
	{
		data = replaceAll(data, regex(`\/\/[^\n]*`), "");
		data = replaceAll(data, regex("\n|\t"), "");
		data = replaceAll(data, regex(`\s{2,}`), "");

		auto clesses = split(data, regex(`[@\}]`));

		if(clesses.length == 0)
		{
			throw new Exception("parse classes is failed, no class struct!!", data);
		}

		foreach(c; clesses)
		{
				auto symbolFlag = split(c, "{");
				
				if(symbolFlag.length == 2)
				{
					
					auto symbolAttr = split(symbolFlag[0], ":");
					
					if(symbolAttr.length != 2)
					{
						throw new Exception("parse symbol  attr is failed,  symbol missing :, " ~ symbolFlag[0]);
					}

					IdlBaseInterface idlInterface;

					switch(symbolAttr[0])
					{
						case SYMBOL_STRUCT:
							idlInterface  = new IdlParseStruct;
							break;

						case SYMBOL_INTERFACE:
							idlInterface = new IdlParseInterface;
							break;	

						default:
							throw new Exception("parse symbol attr is error,  symbol: " ~ symbolAttr[0]);
					}
					
				if(idlInterface.parse(fileName, symbolAttr[1], symbolFlag[1]))
					{
						switch(symbolAttr[0])
						{
							case SYMBOL_STRUCT:
								idlStructList[idlInterface.getName] = cast(IdlParseStruct)idlInterface;
								break;

							case SYMBOL_INTERFACE:
								idlInerfaceList[idlInterface.getName] = idlInterface;
								break;

							default:
								throw new Exception("parse symbol attr is error,  symbol: " ~ symbolAttr[0]);
						}
					}
			}
		}

		this.create_code();
		return true;
	}


	void create_code()
	{
		string serverCodeInterface, serverCodeService;
		string clientCodeInterface, clientCodeService;
		string structCode;
		string flatbufferIdlCode;

		auto serverInterfaceStrings = appender!string();
		formattedWrite(serverInterfaceStrings, "module KissRpc.IDL.%sInterface;\n\n", fileName);
		formattedWrite(serverInterfaceStrings, "import KissRpc.IDL.%sMessage;\n", fileName);
		formattedWrite(serverInterfaceStrings, "import KissRpc.IDL.%sService;\n\n", fileName);



		formattedWrite(serverInterfaceStrings, "import KissRpc.RpcServer;\n");
		formattedWrite(serverInterfaceStrings, "import KissRpc.RpcServerImpl;\n");
		formattedWrite(serverInterfaceStrings, "import KissRpc.RpcResponse;\n");
		formattedWrite(serverInterfaceStrings, "import KissRpc.RpcRequest;\n");
		formattedWrite(serverInterfaceStrings, "import flatbuffers;\n");

		auto server_service_strings = appender!string();
		formattedWrite(server_service_strings, "module KissRpc.IDL.%sService;\n\n", fileName);
		formattedWrite(server_service_strings, "import KissRpc.IDL.%sInterface;\n", fileName);
		formattedWrite(server_service_strings, "import KissRpc.IDL.%sMessage;\n\n", fileName);
		formattedWrite(server_service_strings, "import KissRpc.RpcServer;\n");
		formattedWrite(server_service_strings, "import KissRpc.Unit;\n\n");

		auto client_interface_strings = appender!string();
		formattedWrite(client_interface_strings, "module KissRpc.IDL.%sInterface;\n\n", fileName);
		formattedWrite(client_interface_strings, "import KissRpc.IDL.%sMessage;\n", fileName);
		formattedWrite(client_interface_strings, "import KissRpc.IDL.%sService;\n\n", fileName);

		formattedWrite(client_interface_strings, "import KissRpc.RpcRequest;\n");
		formattedWrite(client_interface_strings, "import KissRpc.RpcClientImpl;\n");
		formattedWrite(client_interface_strings, "import KissRpc.RpcClient;\n");
		formattedWrite(client_interface_strings, "import KissRpc.RpcResponse;\n");
		formattedWrite(client_interface_strings, "import KissRpc.Unit;\n");
		formattedWrite(client_interface_strings, "import flatbuffers;\n");


		auto client_service_strings = appender!string();
		formattedWrite(client_service_strings, "module KissRpc.IDL.%sService;\n\n\n", fileName);
		formattedWrite(client_service_strings, "import KissRpc.IDL.%sInterface;\n", fileName);
		formattedWrite(client_service_strings, "import KissRpc.IDL.%sMessage;\n\n", fileName);
		formattedWrite(client_service_strings, "import KissRpc.RpcClient;\n");
		formattedWrite(client_service_strings, "import KissRpc.Unit;\n\n");



		auto struct_strings = appender!string();
		formattedWrite(struct_strings, "module KissRpc.IDL.%sMessage;\n", fileName);
		formattedWrite(struct_strings, "import std.typetuple;\n\n\n");
	


		foreach(k, v; idlInerfaceList)
		{
			serverCodeInterface ~= v.createServerCodeForInterface(CODE_LANGUAGE.CL_DLANG);
			serverCodeService ~= v.createServerCodeForService(CODE_LANGUAGE.CL_DLANG);

			clientCodeInterface ~= v.createClientCodeForInterface(CODE_LANGUAGE.CL_DLANG);
			clientCodeService ~= v.createClientCodeForService(CODE_LANGUAGE.CL_DLANG);
		}

		foreach(k, v; idlStructList)
		{
			structCode ~= v.createCodeForLanguage(CODE_LANGUAGE.CL_DLANG);
		}

		foreach(k,v; idlStructList)
		{
			flatbufferIdlCode ~= IdlFlatbufferCode.createFlatbufferCode(v);
		}


		auto flatbuffer_strings = appender!string();


		auto modulePath = split(fileName, ".");
		
		if(modulePath.length > 1)
		{
			for(int i = 0; i < modulePath.length-1; ++i)
			{
				outFilePath ~= ("/" ~ modulePath[i]);
				if(!exists(outFilePath))
					mkdir(outFilePath);

				moduleFilePath ~= (modulePath[i] ~ ".");
			}
			
			fileName = modulePath[modulePath.length-1];
		
			formattedWrite(flatbuffer_strings, "namespace KissRpc.IDL.%sflatbuffer;\n\n", moduleFilePath);
			formattedWrite(serverInterfaceStrings, "import KissRpc.IDL.%sflatbuffer.%s;\n\n", moduleFilePath, fileName);
			formattedWrite(client_interface_strings, "import KissRpc.IDL.%sflatbuffer.%s;\n\n", moduleFilePath, fileName);
		}else
		{
			formattedWrite(flatbuffer_strings, "namespace KissRpc.IDL.flatbuffer;\n\n");
			formattedWrite(serverInterfaceStrings, "import KissRpc.IDL.flatbuffer.%s;\n\n",fileName);
			formattedWrite(client_interface_strings, "import KissRpc.IDL.flatbuffer.%s;\n\n", fileName);
		}


		if(!exists(outFilePath ~ "/server/"))
		{
			mkdir(outFilePath ~ "/server/");
			mkdir(outFilePath ~ "/server/flatbuffer/");
		}


		auto file = File(outFilePath ~ "/server/" ~ fileName ~ "Interface.d", "w+");
		file.write(serverInterfaceStrings.data ~ serverCodeInterface);

		file = File(outFilePath ~ "/server/" ~ fileName ~ "Service.d", "w+");
		file.write(server_service_strings.data ~ serverCodeService);

		file = File(outFilePath ~ "/server/" ~ fileName ~ "Message.d", "w+");
		file.write(struct_strings.data ~ structCode);

		file = File(outFilePath ~ "/server/flatbuffer/" ~ fileName ~ ".fbs", "w+");
		file.write(flatbuffer_strings.data ~ flatbufferIdlCode);

		spawnProcess(["flatc", "-d", "-b", outFilePath ~ "/server/flatbuffer/" ~ fileName ~ ".fbs", "--gen-onefile"],
			std.stdio.stdin, std.stdio.stdout, std.stdio.stderr, null, Config.none, outFilePath ~ "/server/flatbuffer/");


		if(!exists(outFilePath ~ "/client/"))
		{
			mkdir(outFilePath ~ "/client/");
			mkdir(outFilePath ~ "/client/flatbuffer/");
		}

		file = File(outFilePath ~ "/client/" ~ fileName ~ "Interface.d", "w+");
		file.write(client_interface_strings.data ~ clientCodeInterface);

		file = File(outFilePath ~ "/client/" ~ fileName ~ "Service.d", "w+");
		file.write(client_service_strings.data ~ clientCodeService);

		file = File(outFilePath ~ "/client/" ~ fileName ~ "Message.d", "w+");
		file.write(struct_strings.data ~ structCode);

		file = File(outFilePath ~ "/client/flatbuffer/" ~ fileName ~ ".fbs", "w+");
		file.write(flatbuffer_strings.data ~ flatbufferIdlCode);

		spawnProcess(["flatc", "-d", "-b", outFilePath ~ "/client/flatbuffer/" ~ fileName ~ ".fbs", "--gen-onefile"],
			std.stdio.stdin, std.stdio.stdout, std.stdio.stderr, null, Config.none, outFilePath ~ "/client/flatbuffer/");
	}

private:
	IdlBaseInterface[string] idlInerfaceList;

	string inFilePath = ".";
	string outFilePath = ".";
	string fileName;
	string moduleFilePath;
}

