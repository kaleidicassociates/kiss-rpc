module KissRpc.IDL.kiss-testInterface;

import KissRpc.IDL.kiss-testMessage;
import KissRpc.IDL.kiss-testService;

import KissRpc.RpcRequest;
import KissRpc.RpcClientImpl;
import KissRpc.RpcClient;
import KissRpc.RpcResponse;
import KissRpc.Unit;

abstract class RpcAddressBookInterface{ 

	this(RpcClient rpClient){ 
		rpImpl = new RpcClientImpl!(RpcAddressBookService)(rpClient); 
	}

	contacts getContactListInterface(string accountName, const RPC_PACKAGE_COMPRESS_TYPE compressType, const int secondsTimeOut, string bindFunc = __FUNCTION__){

		auto req = new RpcRequest(compressType, secondsTimeOut);

		req.push(accountName);

		RpcResponse resp = rpImpl.syncCall(req, bindFunc);

		if(resp.getStatus == RESPONSE_STATUS.RS_OK){
			contacts ret_contacts;

			resp.pop(ret_contacts);

			return ret_contacts;
		}else{
			throw new Exception("rpc sync call error, function:" ~ bindFunc);
		}
	}


	alias RpcgetContactListCallback = void delegate(contacts);

	void getContactListInterface(string accountName, RpcgetContactListCallback rpcCallback, const RPC_PACKAGE_COMPRESS_TYPE compressType, const int secondsTimeOut, string bindFunc = __FUNCTION__){

		auto req = new RpcRequest(compressType, secondsTimeOut);

		req.push(accountName);

		rpImpl.asyncCall(req, delegate(RpcResponse resp){

			if(resp.getStatus == RESPONSE_STATUS.RS_OK){

				contacts ret_contacts;

				resp.pop(ret_contacts);

				rpcCallback(ret_contacts);
			}else{
				throw new Exception("rpc sync call error, function:" ~ bindFunc);
			}}, bindFunc);
	}


	RpcClientImpl!(RpcAddressBookService) rpImpl;
}

