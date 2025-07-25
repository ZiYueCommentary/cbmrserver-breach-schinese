#include "include/uerm.as"

const uint64 DEFAULT_ADMIN = 76561198175577305;

// Admin panel For Breach Mode
namespace AdminPanel
{
	class Admin
	{
		Admin() { }
		Admin(uint64 id, int l) 
		{ 
			steamid = id; 
			level = l;
		}
		uint64 steamid;
		int level;
	}
	
	Admin[] Admins;
	filesystem@ FileSystem = filesystem();
	
	void Register()
	{
		FileSystem.makeDir("admins");
		FileSystem.changeCurrentPath("admins");
		
		RegisterCallback(PlayerKeyAction_c, OnPlayerKeyAction);
		RegisterCallback(PlayerConnect_c, OnPlayerConnect);
		RegisterCallback(PlayerPressPlayer_c, OnPlayerPressPlayer);
		RegisterCallback(ServerConsole_c, OnConsole);
		Load();
	}
	
	void Load()
	{
		Admins.clear();

		array<string>@ files = FileSystem.getFiles();
		for(int i = 0; i < files.size(); i++) {
			file f;

			if(f.open("admins/" + files[i], "r") >= 0)
			{
				while(!f.isEndOfFile()) {
					string line = f.readLine();
					
					array<string>@ values = line.split(":");
					if(values.size() >= 2) {
						if(values[0].trim().lower() == "level") {
							SetAdmin(parseInt(files[i]), parseInt(values[1].trim()));
						}
					}
				}
				
				f.close();
				
				if(files[i].findFirst(".txt") == -1) FileSystem.move(files[i], files[i] + ".txt");
			}
		}
		
		if(Admins.size() == 0) {
			print("[ADMIN PANEL]: No admins found. Loading default admin.");
			SetAdmin(DEFAULT_ADMIN, 5, true);
		}
		
		for(int i = 0; i <= MAX_PLAYERS; i++) {
			Player p = GetPlayer(i);
			if(p != NULL) {
				if(!IsAdmin(p)) p.SetAdmin(false);
				else p.SetAdmin(true);
			}
		}
	}
	
	bool SetAdmin(uint64 steamid, int level, bool save = false)
	{
		bool found = false;
		for(int i = 0; i < Admins.size(); i++)
		{
			if(Admins[i].steamid == steamid)
			{
				Admins[i].level = level;
				print("[ADMIN PANEL]: Updated " + steamid + " to " + level + " level");

				if(level == 0) Admins.removeAt(i);
				
				found = true;
				break;
			}
		}
		
		if(!found) {
			if(level == 0) return false;
			print("[ADMIN PANEL]: Created " + steamid + " with " + level + " level");
			Admins.push_back(Admin(steamid, level));
		}
		
		if(save)
		{
			if(level == 0) FileSystem.deleteFile(steamid + ".txt");
			else {
				file f;
				if(f.open("admins/" + steamid + ".txt", "w") >= 0)
				{
					f.writeString("Level: " + level);
					f.close();
				}
			}
		}	
		
		return true;
	}
	
	bool IsAdmin(Player p)
	{
		if(p.IsAdmin()) return true;
		
		uint64 steamid = parseInt(p.GetSteamID());
		for(int i = 0; i < Admins.size(); i++) {
			if(Admins[i].steamid == steamid && Admins[i].level > 0) return true;
		}
		return false;
	}
	
	int GetAdminLevel(Player p)
	{
		uint64 steamid = parseInt(p.GetSteamID());
		for(int i = 0; i < Admins.size(); i++) {
			if(Admins[i].steamid == steamid) return Admins[i].level;
		}
		return 0;
	}
	
	bool OnConsole(string command)
	{
		if(command == "reloadadmins") {
			Load();
			print("Reloaded admins");
			return false;
		}
		return true;
	}
	
	void OnPlayerConnect(Player p)
	{
		if(p != NULL) {
			if(IsAdmin(p)) {
				p.SetAdmin(true);
				chat.SendPlayer(p, "你正在以管理员身份登录。等级：" + GetAdminLevel(p) + "。&colr[255 127 100]使用 F2 或 /panel 打开管理面板。");
			}
		}
	}
	
	void OnPlayerKeyAction(Player p, int n, int o) 
	{
		if(IsKeyPressed(KEY_F2, n, o)) 
		{
			Show(p);
		}
	}
	
	void OnPlayerPressPlayer(Player src, Player dest)
	{
		if(IsAdmin(src) && GetAdminLevel(src) >= 2)
		{
			ShowPlayer(src, dest);
		}
	}
	
	void Show(Player p)
	{
		if(IsAdmin(p)) {
			if(FileSystem.getSize(p.GetSteamID() + ".txt") == -1) {
				p.SetAdmin(false);
				return;
			}
			
			int level = GetAdminLevel(p);
			string access;
			if(level >= 1) access += "回合控制 (1)\n";
			if(level >= 2) access += "玩家控制 (2)\n";
			if(level >= 3) access += "服务器控制 (3)\n";
			if(level >= 4) access += "管理员控制 (4)\n";
			
			p.ShowDialog(DIALOG_TYPE_LIST, Dialog::Panel, "管理面板", access, "选择", "取消");
		}
	}
	
	void ShowPlayer(Player src, Player dest = NULL)
	{
		if(dest != NULL) src.SetDialogData(dest.GetName() + "\n" + dest.GetIndex() + "\n" + dest.GetSteamID() + "\n" + dest.GetIP());
		src.ShowDialog(DIALOG_TYPE_LIST, Dialog::PlayerPanel, "玩家控制", "封禁\n踢出\n分配身份组\n分配物品\n传送到该玩家\n传送到当前位置\n设置速度\n设置模型\n设置纹理\n设置大小" + (GetAdminLevel(src) >= 4 ? "\n设置管理员权限" : ""), "选择", "取消");
	}
	
	namespace Dialog
	{
		void Panel(Player p, bool result, string input, int item)
		{
			if(result)
			{
				switch(item)
				{
					case 0:
					{
						RoundControlDialog::ShowControl(p);
						break;
					}
					case 1:
					{
						PlayersControlDialog::ShowControl(p);
						break;
					}
					case 2:
					{
						ServerControlDialog::ShowControl(p);
						break;
					}
					case 3:
					{
						AdminControlDialog::ShowControl(p);
						break;
					}
				}
			}
		}
		
		void PlayerPanel(Player p, bool result, string input, int item)
		{
			if(result)
			{
				switch(item)
				{
					case 0:
					{
						if(GetAdminLevel(GetPanelPlayer(p)) >= GetAdminLevel(p) && GetPanelPlayer(p) != p) {
							chat.SendPlayer(p, "你无法在此玩家上使用此命令");
							return;
						}
						string name = SplitString(p.GetDialogData(), "\n", 0);
						string steamid = SplitString(p.GetDialogData(), "\n", 2);
						string ip = SplitString(p.GetDialogData(), "\n", 3);
						p.ShowDialog(DIALOG_TYPE_INPUT, PlayerPanelControl::ContinueBan, "封禁玩家确认", "玩家：" + name + "\nSteam ID: " + steamid + "\nIP 地址：" + ip +"\n输入封禁原因：", "确认", "取消", false);
						break;
					}
					case 1:
					{
						if(GetAdminLevel(GetPanelPlayer(p)) >= GetAdminLevel(p) && GetPanelPlayer(p) != p) {
							chat.SendPlayer(p, "你无法在此玩家上使用此命令");
							return;
						}
						p.ShowDialog(DIALOG_TYPE_MESSAGE, PlayerPanelControl::ConfirmKick, "踢出玩家？", "你确定要踢出玩家 " + SplitString(p.GetDialogData(), "\n", 0) + " 吗？", "踢出", "取消");
						break;
					}
					case 2:
					{
						if(GetAdminLevel(GetPanelPlayer(p)) >= GetAdminLevel(p) && GetPanelPlayer(p) != p) {
							chat.SendPlayer(p, "你无法在此玩家上使用此命令");
							return;
						}
						p.ShowDialog(DIALOG_TYPE_INPUT, PlayerPanelControl::GiveRole, "分配身份组", "输入身份组编号：", "确认", "取消");
						break;
					}
					case 3:
					{
						p.ShowDialog(DIALOG_TYPE_INPUT, PlayerPanelControl::GiveItem, "分配物品", "输入物品名：", "确认", "取消");
						break;
					}
					case 4:
					{
						p.ShowDialog(DIALOG_TYPE_MESSAGE, PlayerPanelControl::TeleportTo, "传送到玩家处", "你确定要传送到玩家处吗？", "确认", "取消");
						break;
					}
					case 5:
					{
						if(GetAdminLevel(GetPanelPlayer(p)) >= GetAdminLevel(p) && GetPanelPlayer(p) != p) {
							chat.SendPlayer(p, "你无法在此玩家上使用此命令");
							return;
						}
						p.ShowDialog(DIALOG_TYPE_MESSAGE, PlayerPanelControl::TeleportMe, "传送到此处", "确定要将玩家传送到此处吗？", "确认", "取消");
						break;
					}
					case 6:
					{
						if(GetAdminLevel(GetPanelPlayer(p)) >= GetAdminLevel(p) && GetPanelPlayer(p) != p) {
							chat.SendPlayer(p, "你无法在此玩家上使用此命令");
							return;
						}
						p.ShowDialog(DIALOG_TYPE_INPUT, PlayerPanelControl::SetSpeed, "设置速度", "输入速度（0.0为默认）", "确认", "取消");
						break;
					}
					case 7:
					{
						if(GetAdminLevel(GetPanelPlayer(p)) >= GetAdminLevel(p) && GetPanelPlayer(p) != p) {
							chat.SendPlayer(p, "你无法在此玩家上使用此命令");
							return;
						}
						p.ShowDialog(DIALOG_TYPE_INPUT, PlayerPanelControl::SetModel, "设置模型", "输入模型 ID (1-16)", "确认", "取消");
						break;
					}
					case 8:
					{
						if(GetAdminLevel(GetPanelPlayer(p)) >= GetAdminLevel(p) && GetPanelPlayer(p) != p) {
							chat.SendPlayer(p, "你无法在此玩家上使用此命令");
							return;
						}
						p.ShowDialog(DIALOG_TYPE_INPUT, PlayerPanelControl::SetTexture, "设置纹理", "输入纹理 ID (1-30)", "确认", "取消");
						break;
					}
					case 9:
					{
						if(GetAdminLevel(GetPanelPlayer(p)) >= GetAdminLevel(p) && GetPanelPlayer(p) != p) {
							chat.SendPlayer(p, "你无法在此玩家上使用此命令");
							return;
						}
						p.ShowDialog(DIALOG_TYPE_INPUT, PlayerPanelControl::SetSize, "设置大小", "输入大小（0.0为默认）", "确认", "取消");
						break;
					}
					case 10:
					{
						if(GetAdminLevel(GetPanelPlayer(p)) >= GetAdminLevel(p)) {
							chat.SendPlayer(p, "你无法在此玩家上使用此命令");
							return;
						}
						p.ShowDialog(DIALOG_TYPE_INPUT, PlayerPanelControl::GiveAdmin, "设置管理员权限", "输入管理员权限（0为移除）", "确认", "取消");
						break;
					}
				}
			}
		}
		
		Player GetPanelPlayer(Player p)
		{
			int index = parseInt(SplitString(p.GetDialogData(), "\n", 1));
			
			if(GetPlayer(index) != NULL && GetPlayer(index).GetSteamID() == SplitString(p.GetDialogData(), "\n", 2))
			{
				return GetPlayer(index);
			}
			return NULL;
		}
			
		namespace PlayerPanelControl
		{
			void ContinueBan(Player p, bool result, string input, int item)
			{
				if(!result || input.findFirst(":::") >= 0) { ShowPlayer(p); return; }
				
				p.SetDialogData(p.GetDialogData() + "\n" + input);
				
				string name = SplitString(p.GetDialogData(), "\n", 0);
				string steamid = SplitString(p.GetDialogData(), "\n", 2);
				string ip = SplitString(p.GetDialogData(), "\n", 3);
				p.ShowDialog(DIALOG_TYPE_INPUT, PlayerPanelControl::ConfirmBan, "封禁玩家确认", "玩家：" + name + "\nSteam ID: " + steamid + "\nIP 地址：" + ip +"\n输入封禁时长（0=无限）：", "封禁", "取消", false);
			}
			
			void ConfirmBan(Player p, bool result, string input, int item)
			{
				if(!result) { ShowPlayer(p); return; }
				
				int minutes = parseInt(input);
				
				string reason = SplitString(p.GetDialogData(), "\n", CountSplitString(p.GetDialogData(), "\n") - 1);
				
				string IP = SplitString(p.GetDialogData(), "\n", 3);
				GlobalBans.Push(SplitString(p.GetDialogData(), "\n", 2), IP, reason, minutes != 0 ? datetime().time + (60 * minutes) : 0);
				GlobalBans.Save();
				chat.Send("&colr[200 0 0]管理员 &r[]" + p.GetName() + "&r[] 已封禁 " + SplitString(p.GetDialogData(), "\n", 0) + "。时间：" + minutes + " 分钟。原因：" + reason);

				for(int i = connPlayers.size() - 1; i >= 0; i--) {
					if(connPlayers[i].GetIP() == IP) { 
						connPlayers[i].Kick(CODE_BANNED);
					}
				}
			}
			
			void ConfirmKick(Player p, bool result, string input, int item)
			{
				if(!result) { ShowPlayer(p); return; }
				int index = parseInt(SplitString(p.GetDialogData(), "\n", 2));
				if(GetPanelPlayer(p) != NULL)
				{
					GetPanelPlayer(p).Kick(CODE_KICKED);
					chat.SendPlayer(p, "成功！");
				}
			}
			
			void GiveRole(Player p, bool result, string input, int item)
			{
				if(!result) { ShowPlayer(p); return; }
				if(GetPanelPlayer(p) != NULL) {
					Role@ role = Roles::Find(parseInt(input));
					if(@role != null) {
						SetPlayerRole(GetPanelPlayer(p), role);
						chat.SendPlayer(p, role.name + " 已成功分配给 " + GetPanelPlayer(p).GetName());
					}
					else chat.SendPlayer(p, "身份组不存在！");
				}
				ShowPlayer(p);
			}
			
			void GiveItem(Player p, bool result, string input, int item)
			{
				if(!result) { ShowPlayer(p); return; }
				if(GetPanelPlayer(p) != NULL) {
					Items it = world.CreateItem(input);
					if(it != NULL) {
						it.SetPicker(GetPanelPlayer(p));
						chat.SendPlayer(p, it.GetTemplateName() + " 已成功分配给 " + GetPanelPlayer(p).GetName());
					}
					else chat.SendPlayer(p, "物品不存在！");
				}
				ShowPlayer(p);
			}
			
			void TeleportTo(Player p, bool result, string input, int item)
			{
				if(!result) { ShowPlayer(p); return; }
				if(GetPanelPlayer(p) != NULL) {
					Entity destEnt = GetPanelPlayer(p).GetEntity();
					p.SetPosition(destEnt.PositionX(), destEnt.PositionY(), destEnt.PositionZ(), GetPanelPlayer(p).GetRoom());
					chat.SendPlayer(p, "成功！");
				}
			}
			
			void TeleportMe(Player p, bool result, string input, int item)
			{
				if(!result) { ShowPlayer(p); return; }
				if(GetPanelPlayer(p) != NULL) {
					Entity destEnt = p.GetEntity();
					GetPanelPlayer(p).SetPosition(destEnt.PositionX(), destEnt.PositionY(), destEnt.PositionZ(), p.GetRoom());
					chat.SendPlayer(p, "成功！");
				}
			}
			
			void SetSpeed(Player p, bool result, string input, int item)
			{
				if(!result) { ShowPlayer(p); return; }
				if(input.length() > 0 && GetPanelPlayer(p) != NULL) {
					GetPanelPlayer(p).SetSpeedMultiplier(parseFloat(input));
					chat.SendPlayer(p, "成功！");
					ShowPlayer(p);
				}
			}
			
			void SetSize(Player p, bool result, string input, int item)
			{
				if(!result) { ShowPlayer(p); return; }
				if(input.length() > 0 && GetPanelPlayer(p) != NULL) {
					GetPanelPlayer(p).SetModelSize(parseFloat(input));
					chat.SendPlayer(p, "成功！");
					ShowPlayer(p);
				}
			}
			
			void SetModel(Player p, bool result, string input, int item)
			{
				if(!result) { ShowPlayer(p); return; }
				if(input.length() > 0 && GetPanelPlayer(p) != NULL) {
					GetPanelPlayer(p).SetModel(parseInt(input));
					chat.SendPlayer(p, "成功！");
					ShowPlayer(p);
				}
			}
			
			void SetTexture(Player p, bool result, string input, int item)
			{
				if(!result) { ShowPlayer(p); return; }
				if(input.length() > 0 && GetPanelPlayer(p) != NULL) {
					GetPanelPlayer(p).SetModelTexture(parseInt(input));
					chat.SendPlayer(p, "成功！");
					ShowPlayer(p);
				}
			}
			
			void GiveAdmin(Player p, bool result, string input, int item)
			{
				if(!result) { ShowPlayer(p); return; }
				if(input.length() > 0 && GetPanelPlayer(p) != NULL) {
					if(GetAdminLevel(p) <= parseInt(input)) {
						chat.SendPlayer(p, "你无法设置该等级");
						return;
					}
						
					SetAdmin(parseInt(GetPanelPlayer(p).GetSteamID()), parseInt(input), true);
					chat.SendPlayer(p, "你将 " + parseInt(input) + " 级管理员权限分配给了 " + GetPanelPlayer(p).GetName());
				}
			}
		}
		
		namespace PlayersControlDialog
		{
			void ShowControl(Player p)
			{
				p.ShowDialog(DIALOG_TYPE_LIST, PlayersControl, "玩家控制", "将所有人传送到此处\n将玩家传送到玩家处\n解封玩家\n使用玩家列表控制 (P)" , "选择", "返回");
			}
			
			void PlayersControl(Player p, bool result, string input, int item)
			{
				if(!result) { Show(p); return; }
				
				switch(item) {
					case 0: 
						p.ShowDialog(DIALOG_TYPE_MESSAGE, TeleportEveryone, "将所有人传送到此处", "你确定要将所有人传送至此处吗？", "确认", "取消");
						break;
					case 1:
						p.ShowDialog(DIALOG_TYPE_INPUT, TeleportPTOP, "n将玩家传送到玩家处", "输入玩家编号（例如[1 2]）", "确认", "取消");
						break;
					case 2:
						p.ShowDialog(DIALOG_TYPE_INPUT, Unban, "解封玩家", "输入 IP 或 SteamID", "解封", "取消");
						break;
				}
			}
		
			void TeleportEveryone(Player p, bool result, string input, int item)
			{
				if(!result) { ShowControl(p); return; }
				for(int i = 0; i < connPlayers.size(); i++) {
					Entity destEnt = p.GetEntity();
					connPlayers[i].SetPosition(destEnt.PositionX(), destEnt.PositionY(), destEnt.PositionZ(), p.GetRoom());
				}
				chat.SendPlayer(p, "成功！");
			}
			
			void TeleportPTOP(Player p, bool result, string input, int item)
			{
				if(!result) { ShowControl(p); return; }
				array<string>@ values = input.split(" ");
				if(values.size() >= 2) {
					int playerid = parseInt(values[0]);
					if(playerid <= MAX_PLAYERS) {
						Player dest = GetPlayer(playerid);
						if(dest != NULL) {
							int playerid2 = parseInt(values[1]);
							if(playerid2 <= MAX_PLAYERS) {
								Player dest2 = GetPlayer(playerid2);
								if(dest2 != NULL) {
									Entity destEnt = dest2.GetEntity();
									dest.SetPosition(destEnt.PositionX(), destEnt.PositionY(), destEnt.PositionZ(), dest2.GetRoom());
						
									chat.SendPlayer(p, dest.GetName() + " 已成功传送至 " + dest2.GetName());
									ShowControl(p);
								}
							}
							return;
						}
					}
				}
				
				ShowControl(p);
				chat.SendPlayer(p, "找不到玩家或身份组");
			}
			
			void Unban(Player p, bool result, string input, int item)
			{
				if(!result) { ShowControl(p); return; }
				if(input.findFirst(".") >= 0 ? GlobalBans.Remove("", input) : GlobalBans.Remove(input, "")) {
					chat.SendPlayer(p, "玩家已解封");
					GlobalBans.Save();
				}
				else chat.SendPlayer(p, "找不到封禁玩家");
				ShowControl(p);
			}
		}
		
		namespace RoundControlDialog
		{
			void ShowControl(Player p)
			{
				p.ShowDialog(DIALOG_TYPE_LIST, RoundControl, "回合控制", "开始回合\n重启回合\n设置大厅倒计时\n设置回合时间\n刷新波数\n广播" , "选择", "返回");
			}
			
			void RoundControl(Player p, bool result, string input, int item)
			{
				if(!result) { Show(p); return; }
				switch(item) 
				{
					case 0:
						p.ShowDialog(DIALOG_TYPE_MESSAGE, StartRound, "开始？", "确定要开始本回合？", "确认", "取消");
						break;
					case 1:
						p.ShowDialog(DIALOG_TYPE_MESSAGE, RestartRound, "重启回合", "确定要重启本回合？", "确认", "取消");
						break;
					case 2:
						p.ShowDialog(DIALOG_TYPE_INPUT, SetLobbyTimer, "设置大厅倒计时", "输入秒数", "确认", "取消");
						break;
					case 3:
						p.ShowDialog(DIALOG_TYPE_INPUT, SetRoundTimer, "设置回合时间", "输入秒数", "确认", "取消");
						break;
					case 4:
						Round::SpawnWave();
						break;
					case 5:
						p.ShowDialog(DIALOG_TYPE_INPUT, Announce, "广播", "输入广播内容：", "确认", "取消");
						break;
				}
			}
			
			void StartRound(Player p, bool result, string input, int item)
			{
				if(!result) { ShowControl(p); return; }
				Round::Start();
			}
			
			void RestartRound(Player p, bool result, string input, int item)
			{
				if(!result) { ShowControl(p); return; }
				Round::Reload();
			}
			
			void SetLobbyTimer(Player p, bool result, string input, int item)
			{
				if(!result) { ShowControl(p); return; }
				if(input.length() > 0) {
					Lobby::SetTimer(parseInt(input));
					chat.SendPlayer(p, "成功！");
				}
			}
			
			void SetRoundTimer(Player p, bool result, string input, int item)
			{
				if(!result || input == "") { ShowControl(p); return; }
				Round::SetTimer(parseUInt(input));
			}
			
			void Announce(Player p, bool result, string input, int item)
			{
				if(!result || input == "") { ShowControl(p); return; }
				chat.Send("[服务器]：" + input);
			}
		}
		
		namespace ServerControlDialog
		{
			void ShowControl(Player p)
			{
				p.ShowDialog(DIALOG_TYPE_LIST, ServerControl, "服务器控制", "Restart server\n" , "选择", "返回");
			}
			
			void ServerControl(Player p, bool result, string input, int item)
			{
				if(!result) { Show(p); return; }
				if(item == 0) {
					p.ShowDialog(DIALOG_TYPE_MESSAGE, RestartServer, "重启服务器", "你确定要重启服务器吗？", "确认", "取消");
				}
			}
			
			void RestartServer(Player p, bool result, string input, int item)
			{
				if(!result) { ShowControl(p); return; }
				Round::End();
			}
		}
		
		namespace AdminControlDialog
		{
			void ShowControl(Player p)
			{
				p.ShowDialog(DIALOG_TYPE_LIST, AdminControl, "管理员控制", "设置管理员权限", "确认");
			}
			
			void AdminControl(Player p, bool result, string input, int item)
			{
				if(result) p.ShowDialog(DIALOG_TYPE_MESSAGE, 0, "提醒", "双击玩家列表里的玩家以设置权限", "确认");
				else Show(p);
			}
		}
	}
}