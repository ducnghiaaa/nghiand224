package com.dpt.demo;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;

import javax.sql.DataSource;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.servlet.ModelAndView;

@Controller
public class register {

	@Autowired
	private DataSource dataSource;

	@Autowired
	private PasswordEncoder passwordEncoder;


	@RequestMapping(value = "register", method = RequestMethod.GET)
	public ModelAndView registerform()
	{
		ModelAndView mv=new ModelAndView("register");

		return mv;
	}


	@RequestMapping(value = "register", method = RequestMethod.POST)
	public ModelAndView register(String firstName,String lastName,String email,String userName,String password)
	{
		// regdate khong nam trong danh sach cot: migration da dat
		// DEFAULT CURRENT_TIMESTAMP cho no.
		String sql = "insert into Employee (first_name, last_name, email, username, password) values (?, ?, ?, ?, ?)";
		try (Connection con = dataSource.getConnection();
				PreparedStatement ps = con.prepareStatement(sql)) {
			ps.setString(1, firstName);
			ps.setString(2, lastName);
			ps.setString(3, email);
			ps.setString(4, userName);
			ps.setString(5, passwordEncoder.encode(password));
			ps.executeUpdate();

		} catch (SQLException ex) {

			ex.printStackTrace();

		}


		ModelAndView mv=new ModelAndView("register");
		mv.addObject("message", "user account has been added for "+userName);
		return mv;
	}


}
