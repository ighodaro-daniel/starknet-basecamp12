#[starknet::interface]
pub trait ICounter<TContractState> {
    fn getCounter(self: @TContractState) -> u32;
    fn increase_counter(ref self: TContractState);
    fn decrease_counter(ref self: TContractState);
    fn reset_counter(ref self: TContractState);
    fn get_win_number(self:@TContractState) ->u32;
}

#[starknet::contract]
pub mod Counter {
    use starknet::{ContractAddress, get_caller_address,get_contract_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use openzeppelin_access::ownable::OwnableComponent;
    use super::ICounter;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use OwnableComponent::InternalTrait;
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

   
     pub const FELT_STRK_CONTRACT: felt252 =
        0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d;

       // Win number - when counter reaches this, caller gets all STRK
    pub const WIN_NUMBER: u32 = 10;   
    
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;
    
    #[storage]
    pub struct Storage {
        counter: u32,
        #[substorage(v0)]
        ownable : OwnableComponent::Storage
    }
    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.counter.write(0);
        self.ownable.initializer(owner);
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Increased: Increased,
        Decreased: Decreased,
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }
    #[derive(Drop, starknet::Event)]
    pub struct Increased {
      pub account: ContractAddress,
        
    }
    #[derive(Drop, starknet::Event)]
    pub struct Decreased {
       pub account: ContractAddress,
    
    }
     pub mod ERROR{
        pub const EMPTY:felt252 = 'decreasing an empty number';

     }

    #[abi(embed_v0)]
    impl ICounterImpl of ICounter<ContractState> {

        fn getCounter(self: @ContractState) -> u32 {
            self.counter.read()
        }


        fn increase_counter(ref self: ContractState, ) {
            let new_value = self.counter.read() + 1;
            //assert!(new_value <= u32::MAX, "counter overflow");
            self.counter.write(new_value);
            self.emit(Increased { account: get_caller_address() });
            if new_value == WIN_NUMBER{

                let caller = get_caller_address();
                let strk_contract_address:ContractAddress = FELT_STRK_CONTRACT.try_into().unwrap();

                let strk_dispatcher = IERC20Dispatcher{contract_address:strk_contract_address};

                let vaultBalance = strk_dispatcher.balance_of(get_contract_address());

                if vaultBalance > 0 {
                    strk_dispatcher.transfer(caller,vaultBalance);

                }
            }
            
        }

        fn decrease_counter(ref self: ContractState) {
            let oldValue = self.counter.read();
            assert(oldValue > 0,ERROR::EMPTY);
            self.counter.write(oldValue - 1 );
            self.emit(Decreased{account: get_caller_address()})
        }

        fn reset_counter(ref self: ContractState) {
            //self.ownable.assert_only_owner();

            // get the caller address
             let caller = get_caller_address();
             let strk_contract_address : ContractAddress = FELT_STRK_CONTRACT.try_into().unwrap();

             //get the erc20 token
             let strk_dispatcher = IERC20Dispatcher{contract_address: strk_contract_address};

             //get the balance of the contract
             let contract_balance = strk_dispatcher.balance_of(get_contract_address());

             if contract_balance > 0 {
             strk_dispatcher.transfer_from(caller,get_contract_address(),contract_balance);
            }

            self.counter.write(0);
        }


        fn get_win_number(self: @ContractState) ->u32 {
         return WIN_NUMBER ;
        } 
    }  
}
